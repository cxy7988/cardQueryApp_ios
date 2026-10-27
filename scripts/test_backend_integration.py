"""Run the Swift client tests against an isolated copy of the real backend services.

Use the backend's existing .venv Python. Campus, SMTP and push calls are mocked;
Flask, Redis, Celery, authentication, SQLite and SSE run normally on loopback.
"""
import argparse
import os
from pathlib import Path
import socket
import subprocess
import sys
import tempfile
import threading
import time
from unittest.mock import patch


def free_port():
    with socket.socket() as listener:
        listener.bind(('127.0.0.1', 0))
        return listener.getsockname()[1]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--backend', required=True, type=Path)
    parser.add_argument('--redis-server', required=True, type=Path)
    args = parser.parse_args()
    backend = args.backend.resolve()
    if not (backend / 'app.py').is_file():
        parser.error('--backend must point to cardQuery_linuxServer')
    binary = args.redis_server.resolve()
    if not binary.is_file():
        parser.error('--redis-server must point to an existing redis-server binary')

    import redis
    from celery.contrib.testing.worker import start_worker
    from werkzeug.serving import make_server

    project = Path(__file__).resolve().parents[1]
    with tempfile.TemporaryDirectory(prefix='cardquery-ios-integration-') as folder:
        root = Path(folder)
        port = free_port()
        with (root / 'redis.log').open('w') as log:
            process = subprocess.Popen([
                str(binary), '--bind', '127.0.0.1', '--port', str(port),
                '--save', '', '--appendonly', 'no', '--dir', folder,
            ], stdout=log, stderr=subprocess.STDOUT)
        try:
            client = redis.Redis(host='127.0.0.1', port=port)
            for _ in range(100):
                try:
                    if client.ping():
                        break
                except redis.RedisError:
                    if process.poll() is not None:
                        raise RuntimeError((root / 'redis.log').read_text())
                    time.sleep(0.05)
            else:
                raise RuntimeError('Isolated Redis did not start')

            os.environ.update({
                'DATABASE_PATH': str(root / 'test.db'), 'REDIS_HOST': '127.0.0.1',
                'REDIS_PORT': str(port), 'REDIS_DB': '0', 'REDIS_PASS': '',
                'CELERY_BROKER_URL': f'redis://127.0.0.1:{port}/1',
                'ADMIN_EMAILS': '', 'APNS_ENABLED': 'false',
            })
            sys.path.insert(0, str(backend))
            import verification_service
            import query_service
            import scheduler_service
            from app import app

            def balances(email, room, config):
                time.sleep(1.2)  # Keep a running task available for SSE reconnect.
                return {
                    'electricity': {'success': True, 'balance': 120.25, 'unit': '度'},
                    'water': {'success': True, 'balance': 88.5, 'unit': '元'},
                }

            celery = verification_service.celery
            celery.loader.import_default_modules()
            server = make_server('127.0.0.1', 0, app, threaded=True)
            thread = threading.Thread(target=server.serve_forever, daemon=True)
            with patch.object(verification_service, 'gen_code', return_value='123456'), \
                 patch.object(verification_service.send_email_code, 'run', return_value=None), \
                 patch.object(query_service, 'query_user_balances', side_effect=balances), \
                 patch.object(scheduler_service.get_scheduler(), 'send_usage_notification', return_value=None), \
                 patch('requests.sessions.Session.request', side_effect=AssertionError('External HTTP is disabled in tests')), \
                 start_worker(celery, pool='solo', perform_ping_check=False, loglevel='WARNING'):
                thread.start()
                env = os.environ.copy()
                env['CARDQUERY_INTEGRATION_URL'] = f'http://127.0.0.1:{server.server_port}'
                env['CLANG_MODULE_CACHE_PATH'] = str(root / 'clang-cache')
                try:
                    result = subprocess.run([
                        'swift', 'test', '--scratch-path', str(root / 'swift-build'),
                        '--cache-path', str(root / 'swift-cache'),
                        '--config-path', str(root / 'swift-config'),
                        '--security-path', str(root / 'swift-security'), '--disable-sandbox',
                    ], cwd=project, env=env, check=False)
                finally:
                    server.shutdown()
                    server.server_close()
                    thread.join(timeout=5)
            return result.returncode
        finally:
            process.terminate()
            process.wait(timeout=5)


if __name__ == '__main__':
    raise SystemExit(main())
