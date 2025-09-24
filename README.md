# InfoEco - Cooperative Management App
Infoeco is an app built by IFRS-Erechim students enrolled as interns in the extension project "Creation of an organizational app for recycling cooperatives."

InfoEco is a comprehensive Flutter application designed to manage the operations of recycling cooperatives. It provides a platform for communication and data management between City Halls (Prefeituras), Cooperatives (Cooperativas), and their members (Cooperados). The app facilitates tracking of collected materials, attendance, financial distributions, and more, with a role-based access system to ensure relevance for each user type.

## ✨ Features

The application is built around a multi-role system, providing tailored functionality for each user type.

#### 👤 Prefeitura (City Hall)
- **Approve Cooperatives**: Review and approve new cooperative registrations.
- **Oversight**: Gain view-only access to data from linked cooperatives, including:
  - Member lists and statuses.
  - Current stock of collected materials.
  - Member attendance records.
  - Historical data on material sales/distributions.

#### 🏢 Cooperativa (Cooperative)
- **Member Management**: Approve new members (cooperados) who register under the cooperative.
- **Material Management**: Define the list of recyclable materials and set their prices per kg.
- **Inventory Tracking**: View the total quantity of materials collected by all members.
- **Financial Distribution (Partilha)**: Initiate and record the sale/distribution of materials, which calculates and logs payouts.
- **Attendance Management**: View, approve, edit, and delete attendance records for all members.
- **Event Scheduling**: Manage a shared event calendar for all members.
- **Document Handling**: Upload and view cooperative-level documents and view documents uploaded by members.

#### 👷 Cooperado (Cooperative Member)
- **Material Submission**: Submit the quantity (in kg) of collected materials.
- **Financial History**: View a personal history of material submissions and the corresponding financial returns from each "partilha".
- **Attendance**: Clock-in and clock-out to track work hours.
- **Shared Calendar**: View events and reminders posted by the cooperative.
- **Document Upload**: Upload and manage personal documents required by the cooperative.

---

## 🚀 Tech Stack

- **Framework**: Flutter
- **Backend**: Firebase
  - **Authentication**: Firebase Authentication (Email/Password & Phone Number/SMS)
  - **Database**: Cloud Firestore
  - **Storage**: Firebase Storage

---


## 🗄️ Firestore Database Schema

The database is structured hierarchically to represent the relationships between entities. A top-level `users` collection is used for fast role lookups on login.
Although it's a simple DB structure and not the most performant, considering the system will be used by a low pre-defined number of people (a maximum of 200 people and only around 5 of them won't be cooperators), this ensures the necessary performance since the most intensive feature used will be the relationship between a cooperator and its cooperative.
