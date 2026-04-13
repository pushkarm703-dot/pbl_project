# 🚦 राहनुमा (Raahnuma) - Your Guide to Safer Streets

![Flutter](https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white)
![Firebase](https://img.shields.io/badge/Firebase-FFCA28?style=for-the-badge&logo=firebase&logoColor=black)
![Dart](https://img.shields.io/badge/Dart-0175C2?style=for-the-badge&logo=dart&logoColor=white)

**A community-driven mobile application for reporting and managing road infrastructure issues with AI validation**

---

## 📖 About

**Raahnuma** is a smart mobile application that allows citizens to report road hazards like potholes and damaged roads. The system uses **AI-based image validation**, **real-time GPS tracking**, and **Firebase backend** to ensure efficient reporting and management.

---

## 🎯 Problem Statement

- Road hazards cause accidents and vehicle damage  
- No proper system for citizens to report issues  
- Authorities face difficulty in prioritizing problems  
- Manual verification wastes time  

---

## 💡 Solution

- Photo-based reporting with GPS location  
- AI validation to filter invalid reports  
- Real-time status tracking  
- Admin dashboard for management  

---

## ✨ Features

### 👥 For Users
- 📸 Capture and submit images  
- 📍 Automatic GPS tagging  
- 🤖 AI validation with confidence score  
- 📊 Track report status  
- 📂 View submitted reports  
- 📡 Offline report submission (auto-sync later)  

### 👨‍💼 For Admin
- 📋 View all reports  
- 🔍 Filter by status  
- ✅ Update report status  
- 🤖 View AI validation results  
- 📊 Dashboard with statistics  

---

## 🤖 AI/ML Features

- TensorFlow Lite model integration  
- Confidence-based validation  
- Real-time image processing  
- Filters invalid submissions  

---

## 🛠️ Tech Stack

- Flutter (Frontend)  
- Dart  
- Firebase Authentication  
- Cloud Firestore  
- Geolocator (GPS)  
- Image Picker  
- Hive (Offline storage)  
- Connectivity Plus  

---

## 📱 Installation

```bash
git clone https://github.com/yourusername/raahnuma.git
cd raahnuma
flutter pub get
flutter run
