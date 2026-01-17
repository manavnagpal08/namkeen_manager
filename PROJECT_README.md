# Namkeen Factory Manager - System Overview

## 1. Project Purpose
**Namkeen Manager** is a comprehensive ERP (Enterprise Resource Planning) system built specifically for a Namkeen/Snack manufacturing factory. It digitizes the entire lifecycle of the business, from buying raw materials (Besan, Oil) to manufacturing batches (Frying, Mixing), packaging them into packets/boxes, and finally selling them to distributors.

---
## 2. Core Modules & Features

### A. Inventory Management
*   **Raw Materials**: Track stock of specific ingredients like *Besan*, *Oil*, *Spices*.
    *   *Feature*: Set minimum thresholds to get "Low Stock" alerts.
    *   *Feature*: Track cost per unit to calculate production costs.
*   **Warehouse (Finished Goods)**: Track ready-to-sell stock.
    *   *Hierarchy*: You can track stock in **Packets**, **Boxes**, or **Master Cartons**.

### B. Product & Recipe Configurator
*   **Products**: Define what you sell (e.g., *Aloo Bhujia*, *Moong Dal*).
*   **Sizes**: Define selling units (e.g., *200g Pouch*, *1kg Box*).
*   **Recipes**: Link Products to Raw Materials.
    *   *Logic*: "To make 100kg of Aloo Bhujia, I need 60kg Besan, 20L Oil, 2kg Spices."
    *   *Automation*: When you produce a batch, the system **automatically deducts** the raw materials from inventory based on this recipe.

### C. Production Management
*   **Batch Creation**: Start a production run (e.g., "Batch #B001 of Aloo Bhujia").
*   **Stages**: Track status (Planned -> Mixing -> Frying -> Packing -> Complete).
*   **Assignments**: Assign specific employees to specific batches (e.g., "Ramesh is assigned to Fry Batch #B001").

### D. Packaging & Hierarchies
*   **Pack Configuration**: Define how you pack your goods.
    *   *Example*: 1 Box = 20 Packets. 1 Carton = 10 Boxes.
*   **Packaging Assignments**: Assign workers to pack loose material into packets/boxes.

### E. Orders & Dispatch
*   **Order Entry**: Create sales orders for customers/distributors.
*   **Stock Check**: System warns if you try to sell more than you have in the Warehouse.
*   **Dispatch Logs**: Track when goods leave the factory and via which transporter.

### F. Hardware Integration
*   **Thermal Printing**: Connect to Bluetooth Thermal Printers to print:
    *   **Receipts**: For customers.
    *   **Packaging Labels**: To stick on Cartons/Boxes with Batch details.

---

## 3. How the "System Logic" Works (The Flow)

1.  **Setup**: You define a **Product** (Bhujia) and its **Recipe** (Besan + Oil).
2.  **Purchase**: You add stock to **Raw Materials** (e.g., Buy 500kg Besan).
3.  **Production**: 
    *   Manager starts a **Batch** for 100kg Bhujia.
    *   **System Action**: *Instantly subtracts* 60kg Besan and 20L Oil from Raw Materials.
4.  **Packaging**:
    *   Workers pack the 100kg batch into 500 packets (200g each).
    *   **System Action**: Adds 500 Packets to **Warehouse Stock**.
5.  **Sales**:
    *   Distributor orders 100 packets.
    *   **System Action**: Subtracts 100 packets from Warehouse Stock and generates an Invoice.

---

## 4. Tech Stack
*   **Framework**: Flutter (Cross-platform: Android/iOS/Web/Windows).
*   **Database**: Firebase Firestore (Real-time, Cloud-hosted).
*   **State Management**: Provider.
*   **UI Style**: Glassmorphism (Modern, translucent aesthetic).

---

## 5. Quick Start (Test Data)
We have added a **"Load Sample Data"** tool in the Dashboard.
*   This instantly creates sample Raw Materials, Products, and Recipes so you can test the flow immediately without manual data entry.
