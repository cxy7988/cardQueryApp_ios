# QueryApp - Campus Fee Query Application

An iOS application designed specifically for campus life, supporting real-time queries of meal card balance, water fees, and electricity fees.

## 📱 Features

### 🔐 Secure Login
- **Email Verification Login**: Use @wku.edu.cn email to receive verification codes
- **Security Assurance**: 5-minute validity period for verification codes with automatic expiration protection
- **Login State Management**: Persistent login state, no need to log in again after app restart

### 🔍 Multiple Queries
- **Meal Card Balance Query**: Real-time campus card balance information
- **Water Fee Query**: Check dormitory water fee balance and usage
- **Electricity Fee Query**: Monitor dormitory electricity fee balance and power consumption

### 🏠 Smart Room Configuration
- Building, floor, and room cascading selection
- JSON data-based room information management
- Configuration completeness validation

### 📊 History Records
- Local persistent storage of query history
- Support for viewing, deleting, and clearing history records
- Visual display of query status

### ⚙️ Personalized Configuration
- **Basic Configuration**: Room information selection
- **Developer Mode**: Custom API parameter configuration
- **Configuration Management**: Save, reset, import and export

## 🎨 Interface Design

### Modern UI
- Native interface built with SwiftUI
- Card-style design with clear information display
- Support for Light/Dark mode adaptation
- Smooth animation effects and interactive feedback

### User Experience
- Dynamic status display for query buttons
- Configuration guidance and error prompts
- Intuitive icons and color differentiation

## 🔧 Technical Architecture

### Framework Technologies
- **SwiftUI**: Declarative UI framework
- **Combine**: Reactive programming
- **UserDefaults**: Local data persistence
- **URLSession**: Network request handling

### Data Management
- Structured configuration management
- JSON data parsing and processing
- Asynchronous network requests and error handling

## 📋 Usage Instructions

### First Use
1. **Login Verification**: Enter your @wku.edu.cn email address
2. **Receive Verification Code**: Check your email and enter the 6-digit verification code
3. **Complete Login**: Automatically enter the main interface after successful verification

### Room Configuration
1. Click the settings button to enter the configuration page
2. Select your building, floor, and room
3. If you need to customize API parameters, enter "Developer Mode"
4. Save settings and return to the main interface

### Query Operations
1. Ensure room information is correctly configured
2. Click the "Query" button to get real-time data
3. View history records to understand usage trends

### Configuration Management
- **Login Authentication**: Must use @wku.edu.cn email for verification
- **Room Configuration**: Must be completed before querying water and electricity fees
- **Card User ID**: Optional configuration, card balance query is skipped when not set
- **Developer Parameters**: Advanced users can customize API interface parameters
- **Logout**: Safe logout available in the settings page

## 🔒 Privacy & Security

- All data is stored locally and not uploaded to third-party servers
- Sensitive configuration information is only saved locally on the device
- Network requests only access official query interfaces

## 🛠 Developer Instructions

### API Interfaces
- **Card Balance**: `https://webapp.xiaofubao.com/card/getCardMoney`
- **Water & Electricity Fees**: `https://application.xiaofubao.com/app/electric/queryRoomSurplus`

### Configuration Parameters
- `cardUserId`: Card query user ID
- `roomUserId`: Water and electricity fee query user ID
- `deviceId`: Device identifier
- `areaId_elec`: Electricity fee query area ID
- `areaId_water`: Water fee query area ID

### Packet Capture for Parameters
1. Use browser developer tools or proxy tools
2. Perform a query on the official query page
3. Get the `shiroJID` value from the Cookie in the request header
4. Get the corresponding ID values from the request parameters


## 📄 License

This project is for learning and personal use only. Please comply with relevant laws, regulations, and school policies.
