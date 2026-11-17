# Lunar Garage (Rework v1.0)

A high-performance, modern FiveM garage and impound management system for **ESX Legacy**, completely overhauled with a sleek dark dashboard UI, live vehicle telemetry, vehicle personalization, and seamless key management.

[![GitHub Release](https://img.shields.io/github/v/release/DarkBytesx/lunar_garage?color=orange&label=Release)](https://github.com/DarkBytesx/lunar_garage/releases/latest)
[![Download ZIP](https://img.shields.io/badge/Download-lunar__garage.zip-success)](https://github.com/DarkBytesx/lunar_garage/releases/download/v1.0/lunar_garage.zip)

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

## 🛠️ Recent Fixes & Improvements (v1.0)

- **Impound State Synchronization**: Unified vehicle state resolution (`resolveVehicleState`) so newly booted servers or despawned vehicles (`stored == 0`) cleanly route to `in_impound` instead of being stuck.
- **Dynamic Facility Filter Bar**: Impound Lot UI dynamically hides the `[In Garage]` filter button, showing only relevant tabs (`[All]`, `[Outside]`, `[Impounded]`, `[⭐ Favorites]`).
- **Dual Outside Actions at Impound**: Active vehicles outside in the city now offer both **Recover Vehicle ($1000)** and **Mark on GPS Waypoint** simultaneously when viewed at the impound facility.
- **Action Dock Button Alignment**: Removed unintended top margin offset and enforced flexbox alignment for pixel-perfect side-by-side buttons in the details action dock.
- **Dedicated `/impound` Modal**: Police and mechanics can use `/impound` as a standalone modal without dimming or loading the entire garage UI behind it.
- **Location Status Accuracy**: Real-time location text displays "City Impound Yard", "Out in the City", or the exact garage facility name.

---

## ⚠️ Need to Know

> [!IMPORTANT]
> - **Key Management Authority**:
>   Key creation is handled server-side upon successful vehicle spawn and retrieval to prevent duplicate key bugs. If you use a different key system than `p_vehiclekeys`, configure your exports in [config/cl_edit.lua](config/cl_edit.lua) and [server/main.lua](server/main.lua).
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
