/*
 * Lunar Garage - Custom NUI Controller
 */

let state = {
  visible: false,
  facilityType: 'garage', // 'garage' | 'impound'
  currentTab: 'personal', // 'personal' | 'society' | 'impound'
  currentFilter: 'all',    // 'all' | 'in_garage' | 'out_garage' | 'favorites'
  searchQuery: '',
  garageIndex: 1,
  garageName: 'Central Garage',
  hasSociety: false,
  vehicles: [],
  selectedVehicle: null,
  impoundTarget: null
};

// Helper: Post NUI Callback to FiveM
function fetchNui(eventName, data = {}) {
  const resourceName = window.GetParentResourceName ? window.GetParentResourceName() : 'lunar_garage';
  return fetch(`https://${resourceName}/${eventName}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json; charset=UTF-8' },
    body: JSON.stringify(data)
  })
  .then(resp => resp.json().catch(() => null))
  .catch(() => null);
}

// Color calculations
function getHealthColor(percent) {
  if (percent > 75) return '#22C55E'; // green
  if (percent > 50) return '#EAB308'; // yellow
  if (percent > 25) return '#FB9B04'; // orange
  return '#EF4444'; // red
}

function getClassIconSvg(classNum) {
  if (classNum === 8) {
    // Motorcycle
    return `<svg class="card-class-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
      <circle cx="5.5" cy="17.5" r="3.5"/><circle cx="18.5" cy="17.5" r="3.5"/><path d="M15 6h-3l-3 6.5h6l3-6.5zm-6 6.5L12 6"/>
    </svg>`;
  } else if (classNum === 13) {
    // Bicycle
    return `<svg class="card-class-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
      <circle cx="5.5" cy="17.5" r="3.5"/><circle cx="18.5" cy="17.5" r="3.5"/><path d="M12 17.5V14l-3-3 4-3 2 3h3"/>
    </svg>`;
  } else if (classNum === 15 || classNum === 16) {
    // Helicopter / Plane
    return `<svg class="card-class-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
      <path d="M4 12h16M12 4v16m-7-5l7-3 7 3"/>
    </svg>`;
  } else if (classNum === 14) {
    // Boat
    return `<svg class="card-class-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
      <path d="M2 19c2 2 4 2 6 0s4-2 6 0 4 2 6 0M4 16l2-8h12l2 8H4z"/>
    </svg>`;
  }
  // Default: Car
  return `<svg class="card-class-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
    <path d="M8 17H16M8 17C8 18.1046 7.10457 19 6 19C4.89543 19 4 18.1046 4 17M8 17C8 15.8954 7.10457 15 6 15C4.89543 15 4 15.8954 4 17M16 17C16 18.1046 16.8954 19 18 19C19.1046 19 20 18.1046 20 17M16 17C16 15.8954 16.8954 15 18 15C19.1046 15 20 15.8954 20 17M10 5V11M4 11L4.33152 9.01088C4.56901 7.58593 4.68776 6.87345 5.0433 6.3388C5.35671 5.8675 5.79705 5.49447 6.31346 5.26281C6.8993 5 7.6216 5 9.06621 5H12.4311C13.3703 5 13.8399 5 14.2662 5.12945C14.6436 5.24406 14.9946 5.43194 15.2993 5.68236C15.6435 5.96523 15.904 6.35597 16.425 7.13744L19 11M4 17H3.6C3.03995 17 2.75992 17 2.54601 16.891C2.35785 16.7951 2.20487 16.6422 2.10899 16.454C2 16.2401 2 15.9601 2 15.4V14.2C2 13.0799 2 12.5198 2.21799 12.092C2.40973 11.7157 2.71569 11.4097 3.09202 11.218C3.51984 11 4.0799 11 5.2 11H17.2C17.9432 11 18.3148 11 18.6257 11.0492C20.3373 11.3203 21.6797 12.6627 21.9508 14.3743C22 14.6852 22 15.0568 22 15.8C22 15.9858 22 16.0787 21.9877 16.1564C21.9199 16.5843 21.5843 16.9199 21.1564 16.9877C21.0787 17 20.9858 17 20.8 17H20"/>
  </svg>`;
}

// Sort vehicles: Favorites first, then alphabetical
function sortVehicles(list) {
  return list.sort((a, b) => {
    const aFav = a.is_favorite ? 1 : 0;
    const bFav = b.is_favorite ? 1 : 0;
    if (aFav !== bFav) return bFav - aFav;
    const aName = (a.nickname || a.label || a.plate || '').toLowerCase();
    const bName = (b.nickname || b.label || b.plate || '').toLowerCase();
    return aName.localeCompare(bName);
  });
}

// Filtered vehicles based on tab, filter buttons, and search input
function getFilteredVehicles() {
  let list = state.vehicles || [];

  // Filter tabs
  if (state.currentFilter === 'in_garage') {
    list = list.filter(v => v.state === 'in_garage');
  } else if (state.currentFilter === 'out_garage') {
    list = list.filter(v => v.state === 'out_garage');
  } else if (state.currentFilter === 'in_impound') {
    list = list.filter(v => v.state === 'in_impound' || v.impound_data);
  } else if (state.currentFilter === 'favorites') {
    list = list.filter(v => v.is_favorite);
  }

  // Search query
  if (state.searchQuery.trim() !== '') {
    const q = state.searchQuery.trim().toLowerCase();
    list = list.filter(v => {
      const matchPlate = v.plate && v.plate.toLowerCase().includes(q);
      const matchLabel = v.label && v.label.toLowerCase().includes(q);
      const matchNick = v.nickname && v.nickname.toLowerCase().includes(q);
      const matchClass = v.className && v.className.toLowerCase().includes(q);
      return matchPlate || matchLabel || matchNick || matchClass;
    });
  }

  return sortVehicles(list);
}

// Render vehicle list in Left Panel
function renderVehicleList() {
  const container = document.getElementById('vehicle-list-container');
  const countTag = document.getElementById('vehicle-count-tag');
  const filtered = getFilteredVehicles();

  countTag.textContent = filtered.length;
  container.innerHTML = '';

  if (filtered.length === 0) {
    container.innerHTML = `
      <div class="panel-empty">
        <svg class="empty-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5">
          <path stroke-linecap="round" stroke-linejoin="round" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
        </svg>
        <span class="empty-title">No Vehicles Found</span>
        <span class="empty-desc">No vehicles match your active tab, filter, or search criteria.</span>
      </div>
    `;
    return;
  }

  filtered.forEach(vehicle => {
    const isSelected = state.selectedVehicle && state.selectedVehicle.plate === vehicle.plate;
    const isHold = vehicle.impound_data && vehicle.impound_data.hold;

    let statusClass = 'status-in_garage';
    let statusText = 'IN GARAGE';

    if (isHold) {
      statusClass = 'status-hold';
      statusText = 'POLICE HOLD';
    } else if (vehicle.state === 'out_garage') {
      statusClass = 'status-out_garage';
      statusText = 'OUTSIDE';
    } else if (vehicle.state === 'in_impound') {
      statusClass = 'status-in_impound';
      statusText = 'IMPOUNDED';
    }

    const card = document.createElement('div');
    card.className = `vehicle-card ${isSelected ? 'selected' : ''}`;
    card.innerHTML = `
      <div class="card-top">
        <div class="card-title-group">
          ${getClassIconSvg(vehicle.class)}
          <span class="card-model-name">${vehicle.label || 'Vehicle'}</span>
          ${vehicle.is_favorite ? '<span class="card-fav-star">⭐</span>' : ''}
        </div>
        <span class="card-status-badge ${statusClass}">${statusText}</span>
      </div>

      <div class="card-sub">
        <span class="card-plate">${vehicle.plate}</span>
        ${vehicle.nickname ? `<span class="card-nickname">"${vehicle.nickname}"</span>` : `<span class="card-class">${vehicle.className || 'Vehicle'}</span>`}
      </div>

      <div class="card-mini-bars">
        <div class="mini-bar-item">
          <div class="mini-bar-label">
            <span>Fuel</span>
            <span>${vehicle.fuel || 100}%</span>
          </div>
          <div class="mini-bar-track">
            <div class="mini-bar-fill" style="width: ${vehicle.fuel || 100}%; background: ${getHealthColor(vehicle.fuel || 100)};"></div>
          </div>
        </div>
        <div class="mini-bar-item">
          <div class="mini-bar-label">
            <span>Body</span>
            <span>${vehicle.body || 100}%</span>
          </div>
          <div class="mini-bar-track">
            <div class="mini-bar-fill" style="width: ${vehicle.body || 100}%; background: ${getHealthColor(vehicle.body || 100)};"></div>
          </div>
        </div>
      </div>
    `;

    card.addEventListener('click', () => {
      selectVehicle(vehicle);
    });

    container.appendChild(card);
  });
}

// Select a vehicle and render Right Panel
function selectVehicle(vehicle) {
  state.selectedVehicle = vehicle;
  renderVehicleList(); // Update selected styling in cards

  const emptyState = document.getElementById('details-empty-state');
  const detailsView = document.getElementById('details-view');

  if (!vehicle) {
    emptyState.classList.remove('hidden');
    detailsView.classList.add('hidden');
    return;
  }

  emptyState.classList.add('hidden');
  detailsView.classList.remove('hidden');

  // Basic Details
  document.getElementById('det-model-name').textContent = vehicle.label || 'Vehicle';
  document.getElementById('det-plate').textContent = vehicle.plate || 'PLATE';
  document.getElementById('det-plate-exact').textContent = vehicle.plate || 'PLATE';
  document.getElementById('det-class-chip').textContent = vehicle.className || 'Automobile';
  document.getElementById('det-garage-name').textContent = vehicle.state === 'in_impound' ? 'City Impound Yard' : (vehicle.state === 'out_garage' ? 'Out in the City' : state.garageName);

  // Nickname
  const nickPill = document.getElementById('det-nickname-pill');
  const nickText = document.getElementById('det-nickname-text');
  if (vehicle.nickname && vehicle.nickname.trim() !== '') {
    nickPill.classList.remove('hidden');
    nickText.textContent = vehicle.nickname;
  } else {
    nickPill.classList.add('hidden');
  }

  // Favorite button
  const favBtn = document.getElementById('btn-toggle-favorite');
  const favLabel = document.getElementById('btn-fav-label');
  if (vehicle.is_favorite) {
    favBtn.classList.add('favorited');
    favLabel.textContent = 'Favorited';
  } else {
    favBtn.classList.remove('favorited');
    favLabel.textContent = 'Favorite';
  }

  // Status Chip & Description
  const statusChip = document.getElementById('det-status-chip');
  const stateDesc = document.getElementById('det-state-desc');
  const isHold = vehicle.impound_data && vehicle.impound_data.hold;

  if (isHold) {
    statusChip.className = 'status-chip status-hold';
    statusChip.textContent = 'POLICE HOLD';
    stateDesc.textContent = 'Held under police impoundment (Hold active)';
  } else if (vehicle.state === 'in_garage') {
    statusChip.className = 'status-chip status-in_garage';
    statusChip.textContent = 'IN GARAGE';
    stateDesc.textContent = 'Safely stored inside garage facility';
  } else if (vehicle.state === 'out_garage') {
    statusChip.className = 'status-chip status-out_garage';
    statusChip.textContent = 'OUTSIDE';
    stateDesc.textContent = 'Currently taken out in the city';
  } else if (vehicle.state === 'in_impound') {
    statusChip.className = 'status-chip status-in_impound';
    statusChip.textContent = 'IMPOUNDED';
    stateDesc.textContent = state.facilityType === 'impound'
      ? 'Stored at city impound yard (Pay fee to retrieve)'
      : 'Stored at city impound yard (Visit Impound Lot to retrieve)';
  }

  // Telemetry: Fuel
  const fuel = vehicle.fuel || 100;
  document.getElementById('det-fuel-val').textContent = `${fuel}%`;
  const fuelBar = document.getElementById('det-fuel-bar');
  fuelBar.style.width = `${fuel}%`;
  fuelBar.style.background = getHealthColor(fuel);

  // Telemetry: Body
  const body = vehicle.body || 100;
  document.getElementById('det-body-val').textContent = `${body}%`;
  const bodyBar = document.getElementById('det-body-bar');
  bodyBar.style.width = `${body}%`;
  bodyBar.style.background = getHealthColor(body);

  // Telemetry: Engine
  const engine = vehicle.engine || 100;
  document.getElementById('det-engine-val').textContent = `${engine}%`;
  const engineBar = document.getElementById('det-engine-bar');
  engineBar.style.width = `${engine}%`;
  engineBar.style.background = getHealthColor(engine);

  // Impound Notice Card
  const impoundCard = document.getElementById('det-impound-card');
  if (vehicle.state === 'in_impound' || vehicle.impound_data) {
    impoundCard.classList.remove('hidden');
    const impData = vehicle.impound_data || {};
    const holdBadge = document.getElementById('det-impound-hold-badge');

    if (impData.hold) {
      holdBadge.textContent = 'POLICE HOLD (LOCKED)';
      holdBadge.className = 'impound-alert-badge status-hold';
    } else {
      holdBadge.textContent = 'CLEARED FOR RELEASE';
      holdBadge.className = 'impound-alert-badge status-in_garage';
    }

    document.getElementById('det-impound-fee').textContent = `$${impData.fee || 1000}`;
    document.getElementById('det-impound-reason').textContent = impData.reason || 'Standard city impound';
    document.getElementById('det-impound-officer').textContent = impData.officer || 'Police Department';
    document.getElementById('det-impound-date').textContent = impData.date || 'N/A';
  } else {
    impoundCard.classList.add('hidden');
  }

  // Action Buttons Dock
  renderActionDock(vehicle);
}

// Render dynamic action buttons in Right Panel
function renderActionDock(vehicle) {
  const dock = document.getElementById('det-actions-dock');
  dock.innerHTML = '';

  const isHold = vehicle.impound_data && vehicle.impound_data.hold;

  if (vehicle.state === 'in_garage') {
    if (state.facilityType === 'impound') {
      const btnInGarage = document.createElement('button');
      btnInGarage.type = 'button';
      btnInGarage.className = 'btn-primary-action btn-disabled';
      btnInGarage.disabled = true;
      btnInGarage.innerHTML = `
        <svg class="btn-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
          <path d="M8 17H16M8 17C8 18.1046 7.10457 19 6 19C4.89543 19 4 18.1046 4 17M8 17C8 15.8954 7.10457 15 6 15C4.89543 15 4 15.8954 4 17M16 17C16 18.1046 16.8954 19 18 19C19.1046 19 20 18.1046 20 17M16 17C16 15.8954 16.8954 15 18 15C19.1046 15 20 15.8954 20 17M10 5V11M4 11L4.33152 9.01088C4.56901 7.58593 4.68776 6.87345 5.0433 6.3388C5.35671 5.8675 5.79705 5.49447 6.31346 5.26281C6.8993 5 7.6216 5 9.06621 5H12.4311C13.3703 5 13.8399 5 14.2662 5.12945C14.6436 5.24406 14.9946 5.43194 15.2993 5.68236C15.6435 5.96523 15.904 6.35597 16.425 7.13744L19 11M4 17H3.6C3.03995 17 2.75992 17 2.54601 16.891C2.35785 16.7951 2.20487 16.6422 2.10899 16.454C2 16.2401 2 15.9601 2 15.4V14.2C2 13.0799 2 12.5198 2.21799 12.092C2.40973 11.7157 2.71569 11.4097 3.09202 11.218C3.51984 11 4.0799 11 5.2 11H17.2C17.9432 11 18.3148 11 18.6257 11.0492C20.3373 11.3203 21.6797 12.6627 21.9508 14.3743C22 14.6852 22 15.0568 22 15.8C22 15.9858 22 16.0787 21.9877 16.1564C21.9199 16.5843 21.5843 16.9199 21.1564 16.9877C21.0787 17 20.9858 17 20.8 17H20"/>
        </svg>
        <span>Vehicle in Garage (Visit Garage to Spawn)</span>
      `;
      dock.appendChild(btnInGarage);
    } else {
      const btnSpawn = document.createElement('button');
      btnSpawn.type = 'button';
      btnSpawn.className = 'btn-primary-action';
      btnSpawn.innerHTML = `
        <svg class="btn-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
          <path d="M8 17H16M8 17C8 18.1046 7.10457 19 6 19C4.89543 19 4 18.1046 4 17M8 17C8 15.8954 7.10457 15 6 15C4.89543 15 4 15.8954 4 17M16 17C16 18.1046 16.8954 19 18 19C19.1046 19 20 18.1046 20 17M16 17C16 15.8954 16.8954 15 18 15C19.1046 15 20 15.8954 20 17M10 5V11M4 11L4.33152 9.01088C4.56901 7.58593 4.68776 6.87345 5.0433 6.3388C5.35671 5.8675 5.79705 5.49447 6.31346 5.26281C6.8993 5 7.6216 5 9.06621 5H12.4311C13.3703 5 13.8399 5 14.2662 5.12945C14.6436 5.24406 14.9946 5.43194 15.2993 5.68236C15.6435 5.96523 15.904 6.35597 16.425 7.13744L19 11M4 17H3.6C3.03995 17 2.75992 17 2.54601 16.891C2.35785 16.7951 2.20487 16.6422 2.10899 16.454C2 16.2401 2 15.9601 2 15.4V14.2C2 13.0799 2 12.5198 2.21799 12.092C2.40973 11.7157 2.71569 11.4097 3.09202 11.218C3.51984 11 4.0799 11 5.2 11H17.2C17.9432 11 18.3148 11 18.6257 11.0492C20.3373 11.3203 21.6797 12.6627 21.9508 14.3743C22 14.6852 22 15.0568 22 15.8C22 15.9858 22 16.0787 21.9877 16.1564C21.9199 16.5843 21.5843 16.9199 21.1564 16.9877C21.0787 17 20.9858 17 20.8 17H20"/>
        </svg>
        <span>Take Out Vehicle</span>
      `;
      btnSpawn.addEventListener('click', () => {
        fetchNui('spawnVehicle', {
          index: state.garageIndex,
          props: vehicle.props
        });
        closeUi();
      });
      dock.appendChild(btnSpawn);
    }

  } else if (vehicle.state === 'out_garage') {
    if (state.facilityType === 'impound') {
      const btnRecover = document.createElement('button');
      btnRecover.type = 'button';
      btnRecover.className = 'btn-primary-action btn-impound-retrieve';
      btnRecover.innerHTML = `
        <svg class="btn-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
          <rect x="2" y="5" width="20" height="14" rx="2"/><line x1="2" y1="10" x2="22" y2="10"/>
        </svg>
        <span>Recover Vehicle ($1000)</span>
      `;
      btnRecover.addEventListener('click', () => {
        fetchNui('retrieveImpound', {
          index: state.garageIndex,
          props: vehicle.props
        });
      });
      dock.appendChild(btnRecover);

      const btnGps = document.createElement('button');
      btnGps.type = 'button';
      btnGps.className = 'btn-primary-action btn-gps';
      btnGps.style.marginTop = '0.6vh';
      btnGps.innerHTML = `
        <svg class="btn-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
          <path d="M21 10c0 7-9 13-9 13s-9-6-9-13a9 9 0 0 1 18 0z"/><circle cx="12" cy="10" r="3"/>
        </svg>
        <span>Mark on GPS Waypoint</span>
      `;
      btnGps.addEventListener('click', () => {
        fetchNui('markGps', { plate: vehicle.plate });
        closeUi();
      });
      dock.appendChild(btnGps);
    } else {
      const btnGps = document.createElement('button');
      btnGps.type = 'button';
      btnGps.className = 'btn-primary-action btn-gps';
      btnGps.innerHTML = `
        <svg class="btn-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
          <path d="M21 10c0 7-9 13-9 13s-9-6-9-13a9 9 0 0 1 18 0z"/><circle cx="12" cy="10" r="3"/>
        </svg>
        <span>Mark on GPS Waypoint</span>
      `;
      btnGps.addEventListener('click', () => {
        fetchNui('markGps', { plate: vehicle.plate });
        closeUi();
      });
      dock.appendChild(btnGps);
    }

  } else if (vehicle.state === 'in_impound') {
    const fee = vehicle.impound_data?.fee || 1000;

    if (state.facilityType !== 'impound') {
      // Player is at a normal garage viewing an impounded car -> GREYED OUT
      const btnAtGarage = document.createElement('button');
      btnAtGarage.type = 'button';
      btnAtGarage.className = 'btn-primary-action btn-disabled';
      btnAtGarage.disabled = true;
      btnAtGarage.title = 'You must be at the Impound Lot to pay fee and retrieve this vehicle';
      btnAtGarage.innerHTML = `
        <svg class="btn-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
          <rect x="2" y="5" width="20" height="14" rx="2"/><line x1="2" y1="10" x2="22" y2="10"/>
        </svg>
        <span>Pay Fee ($${fee}) & Retrieve Vehicle</span>
      `;
      dock.appendChild(btnAtGarage);
    } else {
      // Player is physically at the Impound Lot
      if (isHold) {
        const btnLocked = document.createElement('button');
        btnLocked.type = 'button';
        btnLocked.className = 'btn-primary-action btn-disabled';
        btnLocked.disabled = true;
        btnLocked.innerHTML = `
          <svg class="btn-icon" viewBox="0 0 20 20" fill="currentColor">
            <path fill-rule="evenodd" d="M5 9V7a5 5 0 0110 0v2a2 2 0 012 2v5a2 2 0 01-2 2H5a2 2 0 01-2-2v-5a2 2 0 012-2zm8-2v2H7V7a3 3 0 016 0z" clip-rule="evenodd"/>
          </svg>
          <span>Locked by Police Hold (Release Required)</span>
        `;
        dock.appendChild(btnLocked);
      } else {
        // TURN GREEN!
        const btnRetrieve = document.createElement('button');
        btnRetrieve.type = 'button';
        btnRetrieve.className = 'btn-primary-action btn-impound-retrieve';
        btnRetrieve.innerHTML = `
          <svg class="btn-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
            <rect x="2" y="5" width="20" height="14" rx="2"/><line x1="2" y1="10" x2="22" y2="10"/>
          </svg>
          <span>Pay Fee ($${fee}) & Retrieve Vehicle</span>
        `;
        btnRetrieve.addEventListener('click', () => {
          fetchNui('retrieveImpound', {
            index: state.garageIndex,
            props: vehicle.props
          });
        });
        dock.appendChild(btnRetrieve);
      }
    }
  }
}

// Switch Top Navigation Tab
function setTab(tab) {
  state.currentTab = tab;
  state.selectedVehicle = null;

  document.querySelectorAll('.nav-tab-btn').forEach(btn => {
    btn.classList.toggle('active', btn.getAttribute('data-tab') === tab);
  });

  const mainTitle = document.getElementById('section-main-title');
  const subTitle = document.getElementById('section-sub-title');

  if (tab === 'personal') {
    mainTitle.textContent = 'Personal Vehicles';
    subTitle.textContent = 'Inspect specifications, spawn, and manage vehicles you own.';
  } else if (tab === 'society') {
    mainTitle.textContent = 'Society Vehicles';
    subTitle.textContent = 'Fleet vehicles assigned to your current job organization.';
  } else if (tab === 'impound') {
    mainTitle.textContent = 'Impound Lot';
    subTitle.textContent = 'City seized vehicles with violation notices and release fees.';
  }

  // Request vehicles from client
  fetchNui('getVehicles', {
    category: tab,
    index: state.garageIndex
  }).then(list => {
    if (Array.isArray(list)) {
      state.vehicles = list;
      renderVehicleList();
      selectVehicle(list.length > 0 ? list[0] : null);
    }
  });
}

// Close NUI
function closeUi() {
  document.getElementById('app').classList.add('hidden');
  const garage = document.getElementById('garage-container');
  if (garage) garage.classList.add('hidden');
  document.getElementById('modal-nickname').classList.add('hidden');
  document.getElementById('modal-impound').classList.add('hidden');
  state.visible = false;
  state.impoundTarget = null;
  fetchNui('close');
}

// Open UI handler
function openUi(data) {
  state.visible = true;
  state.facilityType = data.type || 'garage';
  state.garageIndex = data.garageIndex || 1;
  state.garageName = data.garageName || (data.type === 'impound' ? 'City Impound' : 'Central Garage');
  state.vehicles = data.vehicles || [];

  document.getElementById('garage-location-subtitle').textContent = state.garageName;

  state.currentFilter = 'all';
  state.searchQuery = '';
  document.getElementById('search-input').value = '';

  document.querySelectorAll('.filter-btn').forEach(btn => {
    btn.classList.toggle('active', btn.getAttribute('data-filter') === 'all');
  });

  const mainTitle = document.getElementById('section-main-title');
  const subTitle = document.getElementById('section-sub-title');
  if (state.facilityType === 'impound') {
    mainTitle.textContent = 'Impound Lot';
    subTitle.textContent = 'Inspect impounded vehicles, pay release fines, and retrieve your car.';
  } else {
    mainTitle.textContent = 'Personal Vehicles';
    subTitle.textContent = 'Inspect specifications, spawn, and manage your vehicles.';
  }

  // Ensure modal dialogs are hidden and main garage container is shown
  document.getElementById('modal-impound').classList.add('hidden');
  document.getElementById('modal-nickname').classList.add('hidden');
  const garage = document.getElementById('garage-container');
  if (garage) garage.classList.remove('hidden');
  document.getElementById('app').classList.remove('hidden');

  renderVehicleList();
  if (state.vehicles.length > 0) {
    selectVehicle(state.vehicles[0]);
  } else {
    selectVehicle(null);
  }
}

// Open Impound Dialog (Police / Mechanic)
function openImpoundDialog(data) {
  state.impoundTarget = data;
  document.getElementById('impound-modal-title').textContent = `Impound Vehicle [${data.plate}]`;
  document.getElementById('impound-reason-input').value = '';
  document.getElementById('impound-fee-input').value = data.defaultFee || 1000;
  document.getElementById('impound-hold-checkbox').checked = false;

  // Hide main garage container so ONLY the impound modal appears
  const garage = document.getElementById('garage-container');
  if (garage) garage.classList.add('hidden');
  document.getElementById('modal-nickname').classList.add('hidden');

  document.getElementById('app').classList.remove('hidden');
  document.getElementById('modal-impound').classList.remove('hidden');
}

// Nickname Modal Logic
function openNicknameModal() {
  if (!state.selectedVehicle) return;
  document.getElementById('nickname-input').value = state.selectedVehicle.nickname || '';
  document.getElementById('modal-nickname').classList.remove('hidden');
  document.getElementById('nickname-input').focus();
}

function saveNickname() {
  if (!state.selectedVehicle) return;
  const input = document.getElementById('nickname-input');
  const newName = input.value.trim();

  fetchNui('setNickname', {
    plate: state.selectedVehicle.plate,
    nickname: newName
  }).then(res => {
    if (res && res.success) {
      state.selectedVehicle.nickname = newName !== '' ? newName : null;
      document.getElementById('modal-nickname').classList.add('hidden');
      renderVehicleList();
      selectVehicle(state.selectedVehicle);
    }
  });
}

// Toggle Favorite Logic
function toggleFavorite() {
  if (!state.selectedVehicle) return;
  fetchNui('toggleFavorite', {
    plate: state.selectedVehicle.plate
  }).then(res => {
    if (res && res.success) {
      state.selectedVehicle.is_favorite = res.is_favorite;
      renderVehicleList();
      selectVehicle(state.selectedVehicle);
    }
  });
}

// Event Listeners Setup
document.addEventListener('DOMContentLoaded', () => {
  // Close Button
  document.getElementById('btn-close').addEventListener('click', closeUi);

  // Filter Buttons
  document.querySelectorAll('.filter-btn').forEach(btn => {
    btn.addEventListener('click', () => {
      document.querySelectorAll('.filter-btn').forEach(b => b.classList.remove('active'));
      btn.classList.add('active');
      state.currentFilter = btn.getAttribute('data-filter');
      renderVehicleList();
    });
  });

  // Search Input
  document.getElementById('search-input').addEventListener('input', (e) => {
    state.searchQuery = e.target.value;
    renderVehicleList();
  });

  // Refresh Button
  document.getElementById('btn-refresh').addEventListener('click', () => {
    fetchNui('getVehicles', {
      category: 'personal',
      index: state.garageIndex
    }).then(list => {
      if (Array.isArray(list)) {
        state.vehicles = list;
        renderVehicleList();
        selectVehicle(list.length > 0 ? list[0] : null);
      }
    });
  });

  // Favorite button
  document.getElementById('btn-toggle-favorite').addEventListener('click', toggleFavorite);

  // Edit Nickname
  document.getElementById('btn-edit-nickname').addEventListener('click', openNicknameModal);
  document.getElementById('btn-close-nickname-modal').addEventListener('click', () => {
    document.getElementById('modal-nickname').classList.add('hidden');
  });
  document.getElementById('btn-cancel-nickname').addEventListener('click', () => {
    document.getElementById('modal-nickname').classList.add('hidden');
  });
  document.getElementById('btn-save-nickname').addEventListener('click', saveNickname);
  document.getElementById('nickname-input').addEventListener('keydown', (e) => {
    if (e.key === 'Enter') saveNickname();
  });

  // Impound Modal Listeners
  document.getElementById('btn-close-impound-modal').addEventListener('click', closeUi);
  document.getElementById('btn-cancel-impound').addEventListener('click', closeUi);
  document.getElementById('btn-confirm-impound').addEventListener('click', () => {
    const reason = document.getElementById('impound-reason-input').value.trim();
    const fee = parseInt(document.getElementById('impound-fee-input').value, 10) || 1000;
    const hold = document.getElementById('impound-hold-checkbox').checked;

    if (!reason) {
      document.getElementById('impound-reason-input').focus();
      return;
    }

    fetchNui('submitImpound', {
      plate: state.impoundTarget?.plate,
      netId: state.impoundTarget?.netId,
      reason: reason,
      fee: fee,
      hold: hold
    });

    closeUi();
  });

  // Escape Key Handling
  window.addEventListener('keydown', (e) => {
    if (e.key === 'Escape') {
      const modalNick = document.getElementById('modal-nickname');
      const modalImp = document.getElementById('modal-impound');
      if (!modalNick.classList.contains('hidden')) {
        modalNick.classList.add('hidden');
        return;
      }
      if (!modalImp.classList.contains('hidden')) {
        closeUi();
        return;
      }
      if (state.visible) {
        closeUi();
      }
    }
  });

  // Window NUI Message Listener
  window.addEventListener('message', (event) => {
    const msg = event.data;
    if (!msg || !msg.action) return;

    if (msg.action === 'open') {
      openUi(msg);
    } else if (msg.action === 'close') {
      closeUi();
    } else if (msg.action === 'openImpoundDialog') {
      openImpoundDialog(msg);
    }
  });
});
