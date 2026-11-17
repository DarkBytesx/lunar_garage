# Lunar Garage (Rework v1.5)

A high-performance, modern FiveM garage and impound management system for **ESX Legacy**, completely overhauled with a sleek dark dashboard UI, live vehicle telemetry, vehicle personalization, and seamless key management.

[![GitHub Release](https://img.shields.io/github/v/release/DarkBytesx/lunar_garage?color=orange&label=Release)](https://github.com/DarkBytesx/lunar_garage/releases/latest)
[![Download ZIP](https://img.shields.io/badge/Download-lunar__garage.zip-success)](https://github.com/DarkBytesx/lunar_garage/releases/download/v1.5/lunar_garage.zip)

---

## 📷 Previews

### 🚗 Main Garage Interface & Live Telemetry
![Main UI](screenshots/Main%20UI.png)

### 📋 Impounded Vehicles List & Fees
![Impounded Cars](screenshots/Impounded%20Cars.png)

### 📍 Impound Lot Site & Physical Retrieval
![Impound Site](screenshots/impound%20site.png)

### 🔑 Single-Authority Key Integration (`p_vehiclekeys`)
![Key Integration](screenshots/p_vehiclekeys%20Integration.png)

### ✏️ Custom Vehicle Nickname System
![Set Nickname](screenshots/Set%20NickName.png)

---

## ✨ Features

- **Modern Dark Dashboard UI**:
  - Clean, responsive dual-panel layout engineered with dynamic viewport units (`vh`/`vw`) for crisp rendering across 1080p, 1440p, and 4K displays.
  - Dedicated asset structure (`web/assets/`) with lightweight vector SVG icons for vehicles, engine diagnostics, and fuel monitoring.
  - Smooth slide animations, styled scrollbars, and intuitive controls.

- **Vehicle Telemetry & Condition Monitoring**:
  - Live **Fuel Level** gauge with percentage and visual meter.
  - Live **Body Integrity** monitor with dynamic color indicators (Green / Yellow / Red).
  - Live **Engine Condition** monitor tracking mechanical health.

- **Smart Impound & Location Workflow**:
  - **Single-List Visibility**: All owned vehicles—whether parked in a garage, spawned outside, or impounded—are accessible from one clean interface.
  - **Physical Retrieval Validation**:
    - When viewing an impounded vehicle from a regular garage, the retrieve action is grayed out with a clear notice.
    - When at an **Impound Lot**, the button turns vibrant green and allows instant payment and vehicle retrieval.
  - **Police Hold Support**: Locked impounds display reason, ticketing officer, date, and hold badge.
  - **Transparent `/impound` Command**: Dedicated in-game prompt for police and mechanics that floats seamlessly over the game world.

- **Vehicle Personalization & Quick Access**:
  - **Favorites System**: Star your most-used vehicles to pin them to the top of your list.
  - **Custom Nicknames**: Assign personalized names to your vehicles with instant local storage saving.
  - **Fast Search & Filter Bar**: Filter by *All*, *In Garage*, *Outside*, *Impounded*, or *Favorites*, with instant search across model names, plates, and custom nicknames.
  - **GPS Waypoint Tracking**: Set a GPS marker on the map to find vehicles parked outside in the city.

- **Single-Authority Key Integration (`p_vehiclekeys`)**:
  - Authoritative key issuance: Player receives exactly **1 key** when taking out or retrieving a vehicle.
  - Duplicate key checks prevent inventory clutter.
  - Automatic key removal when storing a vehicle back into a garage or impound lot.

---

## 🛠️ Recent Fixes & Improvements

### Version 1.5
- **Verbose Diagnostics & Comprehensive Debug Mode (`Config.Debug`)**: Added detailed debug logging across both client (F8 console) and server terminal for every stage of the vehicle lifecycle (take out, retrieve, save, lock status, and key granting/removal).
- **Authoritative Server Key Management**: Keys are reliably issued directly on the server upon vehicle spawn (via `takeOutVehicle` and `retrieveVehicle`) with `ox_inventory:Search` count verification to ensure players receive exactly **1 key** (no duplicates, no misses).
- **Zero-Touch Stock `p_vehiclekeys` Compatibility**: Fully compliant with unmodified stock `p_vehiclekeys` without requiring any edits or fragile client-side entity lookups.
- **Automatic Inventory Key Cleanup**: When a vehicle is saved back into the garage, its corresponding `car_key` item is cleanly removed from the player's inventory on the server.

### Version 1.4
- **Official Client Key API Implementation**: Replaced invalid export checks with direct invocation of the official `exports['p_vehiclekeys']:createKey(plate, vehicle)` client export from the pScripts documentation.
- **Safe `ox_inventory` Key Verification**: Verified existing keys directly through `ox_inventory:Search` to guarantee players receive exactly **1 key** without runtime export errors.

### Version 1.3
- **Single-Authority Key Issuance**: Delegated key issuance strictly to client-side API to eliminate double-key creation.

### Version 1.2
- **Zero-Touch Stock `p_vehiclekeys` Support**: Full native compatibility with official, unmodified [PiotreeQ/p_vehiclekeys](https://github.com/PiotreeQ/p_vehiclekeys). Zero modifications or file edits are needed on `p_vehiclekeys`.
- **Universal Multi-Layer Key Pipeline**:
  - Leverages built-in `wasabi_carlock`, `Renewed-Vehiclekeys`, and `qb-vehiclekeys` compatibility shims dynamically provided by `p_vehiclekeys`.
  - Direct integration with `ox_inventory` for `car_key` item metadata checking and cleanup upon vehicle parking.
  - Client-side immediate responsiveness via `exports['p_vehiclekeys']:removeKey`.
- **Contract Key Transfer Optimization**: Vehicle contracts automatically remove old keys and grant the buyer keys through the universal pipeline.

### Version 1.1
- **Impound State Synchronization**: Unified vehicle state resolution (`resolveVehicleState`) so newly booted servers or despawned vehicles (`stored == 0`) cleanly route to `in_impound` instead of being stuck.
- **Dynamic Facility Filter Bar**: Impound Lot UI dynamically hides the `[In Garage]` filter button, showing only relevant tabs (`[All]`, `[Outside]`, `[Impounded]`, `[⭐ Favorites]`).
- **Dual Outside Actions at Impound**: Active vehicles outside in the city now offer both **Recover Vehicle ($1000)** and **Mark on GPS Waypoint** simultaneously when viewed at the impound facility.
- **Action Dock Button Alignment**: Removed unintended top margin offset and enforced flexbox alignment for pixel-perfect side-by-side buttons in the details action dock.
- **Dedicated `/impound` Modal**: Police and mechanics can use `/impound` as a standalone modal without dimming or loading the entire garage UI behind it.
- **Location Status Accuracy**: Real-time location text displays "City Impound Yard", "Out in the City", or the exact garage facility name.

---

## ⚠️ Need to Know

> [!IMPORTANT]
> - **Key Management Authority & Compatibility**:
>   Compatible out-of-the-box with **unmodified stock [p_vehiclekeys](https://github.com/PiotreeQ/p_vehiclekeys)**, `wasabi_carlock`, `Renewed-Vehiclekeys`, and `ox_inventory`. No edits to your keys script are required. Key creation and removal are handled authoritatively to eliminate duplicate keys.
> - **Impound Fee Collection**:
>   Impound fees are deducted upon vehicle retrieval at the impound facility. Ensure the player has adequate cash/bank funds.
> - **UI Asset Streaming**:
>   All icons (`car.svg`, `engine.svg`, `fuel.svg`) reside in `web/assets/` and are registered in `fxmanifest.lua` under `files`. Do not move them out of this folder.
> - **Vehicle State Sync**:
>   Vehicle states (`in_garage`, `out_garage`, `in_impound`) sync directly with `owned_vehicles` in your database (`oxmysql`). Vehicles despawned or stored update their coordinates and condition properties automatically.

---

## 📦 Dependencies

- **[es_extended](https://github.com/esx-framework/esx_core)** (ESX Legacy 1.8+)
- **[ox_lib](https://github.com/overextended/ox_lib)**
- **[oxmysql](https://github.com/overextended/oxmysql)**
- **[p_vehiclekeys](https://github.com/)** *(or compatible vehicle keys export)*

---

## 🚀 Installation

1. Place `lunar_garage` into your server's `resources` directory (e.g. `resources/[testing]/lunar_garage`).
2. Import the included database setup SQL file located in `install/` if running for the first time.
3. Configure your garage locations, impound locations, and pricing in `config/config.lua`.
4. Ensure the resource starts in your `server.cfg`:
   ```cfg
   ensure ox_lib
   ensure oxmysql
   ensure p_vehiclekeys
   ensure lunar_garage
   ```

---

## 🛠️ Configuration

Configure garages, markers, spawn points, and society settings in:
- `config/config.lua` – Core garage & impound coordinates, blips, fees, and camera angles.
- `config/cl_edit.lua` – Client-side notification, keys, and fuel system bridges.
- `config/sv_config.lua` – Server callbacks, logs, and database table configurations.
