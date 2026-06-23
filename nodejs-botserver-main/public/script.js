function showTab(tabId) {
    document.querySelectorAll('.tab-content').forEach(tab => {
        tab.classList.remove('active');
    });
    
    document.querySelectorAll('.tab').forEach(tab => {
        tab.classList.remove('active');
    });
    
    document.getElementById(tabId).classList.add('active');
    
    Array.from(document.querySelectorAll('.tab')).find(tab => 
        tab.getAttribute('onclick').includes(tabId)
    ).classList.add('active');

    if (tabId === 'locations-tab') {
        requestAnimationFrame(renderGuildMinimap);
    }
    if (tabId === 'nav-debug-tab') {
        fetchNavDebug();
    }
    if (tabId === 'access-tab') {
        fetchDashboardUsers();
    }
}

let refreshFailed = false;
let guildLocations = [];
let selectedGuildLocation = null;
let selectedGuildFloor = null;
let guildMapZoom = 2;
let guildMapFollowSelected = true;
let guildMapCenter = null;
let guildMapDragging = null;
let guildMapRenderQueued = false;
let tierOrbs = null;
let showWolfDeaths = true;
let showWolfHeatmap = true;
let wolfHeatmapRange = 'all';
const WOLF_HEATMAP_FLOOR = 7;
const WOLF_HEATMAP_BUCKET_SIZE = 5;
let wolfHeatmapRegional = true;
let wolfHeatmapByFloor = false;
let wolfHeatmapProjectZ7 = true;
let authUser = null;
let dashboardUsers = [];
let navDebugEvents = [];
let navDebugScouts = [];

function isMemberUnderPk(member) {
    return Boolean(member?.underPkAttack || member?.targetPlayer);
}

function isMemberMarkedLeader(member) {
    return Boolean(member?.leader || member?.highlighted);
}

function isMemberMarkedCaller(member) {
    return Boolean(member?.caller || member?.dashboardCaller);
}

function queueGuildMinimapRender() {
    if (guildMapRenderQueued) return;
    guildMapRenderQueued = true;
    requestAnimationFrame(() => {
        guildMapRenderQueued = false;
        renderGuildMinimap();
    });
}

function fetchStats() {
    if (refreshFailed) return;
    fetch('/api/stats')
        .then(response => {
            if (response.status === 401) {
                window.location.href = '/login';
                throw new Error('Login required');
            }
            if (!response.ok) throw new Error(response.statusText);
            return response;
        })
        .then(response => response.json())
        .then(data => {
            document.getElementById('connections').textContent = data.connections;
            document.getElementById('channels').textContent = data.channelCount;
            document.getElementById('packets').textContent = data.packets;
            
            document.getElementById('ws-blocked').textContent = data.blocked;
            document.getElementById('http-allowed').textContent = data.httpAllowedRequests;
            document.getElementById('http-blocked').textContent = data.httpBlockedRequests;
            authUser = data.authUser || null;
            updateAccessVisibility();

            const channelsBody = document.getElementById('channels-body');
            channelsBody.innerHTML = '';
            
            Object.entries(data.channelDetails).forEach(([name, details]) => {
                const row = document.createElement('tr');
                row.innerHTML = `
                    <td data-label="Name">${name}</td>
                    <td data-label="# of Users">${details.users}</td>
                    <td data-label="Created">${details.created}</td>
                `;

                channelsBody.appendChild(row);
            });
            
            const usersBody = document.getElementById('users-body');
            usersBody.innerHTML = '';
            
            data.users.forEach(user => {
                const row = document.createElement('tr');
                
                row.innerHTML = `
                    <td data-label="Name">${user.name}</td>
                    <td data-label="Channel">${user.channel}</td>
                    <td data-label="Ping">${user.ping} ms</td>
                    <td data-label="Messages">${user.messages}</td>
                    <td data-label="Packets">${user.packets}</td>
                    <td data-label="Connected Time">${user.connectedTime}</td>
                `;
                usersBody.appendChild(row);
            });
            
            const charactersBody = document.getElementById('characters-body');
            charactersBody.innerHTML = '';
            
            data.characters.forEach(character => {
                const row = document.createElement('tr');
                const vocationValue = character.vocationKey || character.vocation;
                const vocationClass = getVocationClass(vocationValue);
                const vocationName = character.vocationLabel || getVocationName(vocationValue);
                const levelColor = getLevelColor(character.level);
                
                row.innerHTML = `
                    <td data-label="Character">${character.name}</td>
                    <td data-label="Level"><span class="level-badge" style="background-color: ${levelColor}">${character.level}</span></td>
                    <td data-label="Vocation"><span class="vocation-badge ${vocationClass}">${vocationName}</span></td>

                    <td data-label="Health">
                        <div class="progress-container">
                            <div class="hp-bar">
                                <div class="hp-bar-fill" style="width: ${character.healthPercent || 0}%"></div>
                            </div>
                            <div class="progress-label">
                                <span>${character.health || 0}</span>
                                <span>${character.maxHealth || 0}</span>
                            </div>
                        </div>
                    </td>
                    <td data-label="Mana">
                        <div class="progress-container">
                            <div class="mana-bar">
                                <div class="mana-bar-fill" style="width: ${character.manaPercent || 0}%"></div>
                            </div>
                            <div class="progress-label">
                                <span>${character.mana || 0}</span>
                                <span>${character.maxMana || 0}</span>
                            </div>
                        </div>
                    </td>
                    <td data-label="Experience">
                        <div class="progress-container">
                            <div class="exp-bar">
                                <div class="exp-bar-fill" style="width: ${character.expPercent || 0}%"></div>
                            </div>
                            <div class="progress-label">
                                <span>${formatNumber(character.experience || 0)}</span>
                            </div>
                        </div>
                    </td>
                    <td data-label="Location">${character.location || 'Unknown'}</td>
                    <td data-label="Last Update">${character.lastUpdate || 'Never'}</td>
                `;
                charactersBody.appendChild(row);
            });

            guildLocations = (data.guildLocations || []).filter(member =>
                Number.isFinite(Number(member.x)) &&
                Number.isFinite(Number(member.y)) &&
                Number.isFinite(Number(member.z))
            );
            guildLocations.sort((a, b) => String(a.name || '').localeCompare(String(b.name || '')));
            const refreshedSelection = guildLocations.find(member => member.name === selectedGuildLocation?.name);
            if (refreshedSelection) {
                selectedGuildLocation = refreshedSelection;
                if (guildMapFollowSelected) {
                    guildMapCenter = positionFrom(refreshedSelection);
                    selectedGuildFloor = Number(refreshedSelection.z);
                }
            } else {
                selectedGuildLocation = guildLocations[0] || null;
                selectedGuildFloor = selectedGuildLocation ? Number(selectedGuildLocation.z) : null;
                guildMapCenter = selectedGuildLocation ? positionFrom(selectedGuildLocation) : null;
            }
            renderGuildLocationsTable();
            tierOrbs = data.tierOrbs || null;
            renderTierOrbs();
            renderGuildMinimap();
            if (document.getElementById('nav-debug-tab')?.classList.contains('active')) {
                fetchNavDebug();
            }
            
            document.getElementById('ws-uptime').textContent = data.wsUptime || '-';
            document.querySelector('.ws-uptime').setAttribute('title', 'WebSocket Started: ' + (data.wsStarted || 'N/A'));

            document.getElementById('last-updated').textContent = 'Last updated: ' + new Date().toLocaleTimeString();

        })
        .catch(error => {
            console.error('Error fetching stats:', error);
            refreshFailed = true;
            clearInterval(refreshInterval);
        });
}

function escapeHtml(value) {
    return String(value ?? '')
        .replace(/&/g, '&amp;')
        .replace(/</g, '&lt;')
        .replace(/>/g, '&gt;')
        .replace(/"/g, '&quot;')
        .replace(/'/g, '&#39;');
}

function guildCoords(member) {
    if (!member) return '-';
    return `${member.x}, ${member.y}, ${member.z}`;
}

function sameFloor(a, b) {
    return a && b && Number(a.z) === Number(b.z);
}

function guildDistance(member, focus) {
    if (!sameFloor(member, focus)) return '-';
    const dx = Math.abs(Number(member.x) - Number(focus.x));
    const dy = Math.abs(Number(member.y) - Number(focus.y));
    return `${Math.max(dx, dy)} sqm`;
}

function selectGuildLocation(name) {
    const found = guildLocations.find(member => member.name === name);
    if (!found) return;
    selectedGuildLocation = found;
    selectedGuildFloor = Number(found.z);
    guildMapFollowSelected = true;
    guildMapCenter = positionFrom(found);
    const followToggle = document.getElementById('guild-map-follow-selected');
    if (followToggle) followToggle.checked = true;
    renderGuildLocationsTable();
    renderGuildMinimap();
}

function setGuildMapFollow(enabled) {
    guildMapFollowSelected = Boolean(enabled);
    const followToggle = document.getElementById('guild-map-follow-selected');
    if (followToggle) followToggle.checked = guildMapFollowSelected;
    if (guildMapFollowSelected && selectedGuildLocation) {
        guildMapCenter = positionFrom(selectedGuildLocation);
        selectedGuildFloor = Number(selectedGuildLocation.z);
    } else if (!guildMapCenter && selectedGuildLocation) {
        guildMapCenter = positionFrom(selectedGuildLocation);
    }
    renderGuildMinimap();
}

function panGuildMap(dx, dy) {
    const base = guildMapCenter || positionFrom(selectedGuildLocation);
    if (!base) return;
    guildMapFollowSelected = false;
    const followToggle = document.getElementById('guild-map-follow-selected');
    if (followToggle) followToggle.checked = false;
    guildMapCenter = {
        x: Number(base.x) + dx,
        y: Number(base.y) + dy,
        z: Number.isFinite(Number(selectedGuildFloor)) ? Number(selectedGuildFloor) : Number(base.z)
    };
    renderGuildMinimap();
}

function beginGuildMapDrag(event) {
    const ignored = event.target.closest('.guild-map-pin, .map-controls, button, input, select, label');
    if (ignored) return;
    const base = guildMapCenter || positionFrom(selectedGuildLocation);
    if (!base) return;
    guildMapFollowSelected = false;
    const followToggle = document.getElementById('guild-map-follow-selected');
    if (followToggle) followToggle.checked = false;
    guildMapDragging = {
        pointerId: event.pointerId,
        startX: event.clientX,
        startY: event.clientY,
        center: { x: Number(base.x), y: Number(base.y), z: Number(selectedGuildFloor) || Number(base.z) }
    };
    event.currentTarget.setPointerCapture?.(event.pointerId);
    event.currentTarget.classList.add('dragging');
    event.preventDefault();
}

function moveGuildMapDrag(event) {
    if (!guildMapDragging || guildMapDragging.pointerId !== event.pointerId) return;
    const dx = (event.clientX - guildMapDragging.startX) / guildMapZoom;
    const dy = (event.clientY - guildMapDragging.startY) / guildMapZoom;
    guildMapCenter = {
        x: guildMapDragging.center.x - dx,
        y: guildMapDragging.center.y - dy,
        z: Number.isFinite(Number(selectedGuildFloor)) ? Number(selectedGuildFloor) : guildMapDragging.center.z
    };
    queueGuildMinimapRender();
}

function endGuildMapDrag(event) {
    if (!guildMapDragging || guildMapDragging.pointerId !== event.pointerId) return;
    event.currentTarget.releasePointerCapture?.(event.pointerId);
    event.currentTarget.classList.remove('dragging');
    guildMapDragging = null;
}

function clampNumber(value, min, max) {
    return Math.max(min, Math.min(max, value));
}

function changeGuildMapZoom(direction) {
    const steps = [0.5, 1, 2, 4, 8];
    const currentIndex = steps.indexOf(guildMapZoom);
    const nextIndex = clampNumber(currentIndex + direction, 0, steps.length - 1);
    guildMapZoom = steps[nextIndex] || 2;
    renderGuildMinimap();
}

function changeGuildMapFloor(direction) {
    if (!selectedGuildLocation && !guildMapCenter) return;
    const base = guildMapCenter || positionFrom(selectedGuildLocation);
    const currentFloor = Number.isFinite(Number(selectedGuildFloor))
        ? Number(selectedGuildFloor)
        : Number(base?.z);
    selectedGuildFloor = clampNumber(currentFloor + direction, 0, 15);
    guildMapFollowSelected = false;
    const followToggle = document.getElementById('guild-map-follow-selected');
    if (followToggle) followToggle.checked = false;
    if (base) {
        guildMapCenter = { x: Number(base.x), y: Number(base.y), z: selectedGuildFloor };
    }
    renderGuildMinimap();
}

function goToHeatmapFloor() {
    const latestDeath = (tierOrbs?.deaths || []).map(death => positionFrom(death)).find(Boolean);
    const base = latestDeath || guildMapCenter || positionFrom(selectedGuildLocation);
    if (!base) return;
    selectedGuildFloor = WOLF_HEATMAP_FLOOR;
    guildMapCenter = { x: Number(base.x), y: Number(base.y), z: WOLF_HEATMAP_FLOOR };
    guildMapFollowSelected = false;
    const followToggle = document.getElementById('guild-map-follow-selected');
    if (followToggle) followToggle.checked = false;
    renderGuildMinimap();
}

function renderGuildLocationsTable() {
    const locationsBody = document.getElementById('locations-body');
    if (!locationsBody) return;
    locationsBody.innerHTML = '';

    guildLocations.forEach(member => {
        const row = document.createElement('tr');
        const vocationValue = member.vocationKey || member.vocation;
        const vocationClass = getVocationClass(vocationValue);
        const vocationName = member.vocationLabel || getVocationName(vocationValue);
        const levelColor = getLevelColor(member.level);
        const selected = selectedGuildLocation && selectedGuildLocation.name === member.name;
        if (selected) row.classList.add('selected-row');
        if (isMemberUnderPk(member)) row.classList.add('pk-row');
        if (member.dead) row.classList.add('dead-row');
        const statusLabel = member.dead ? 'Dead' : (isMemberUnderPk(member) ? 'PK' : 'OK');
        const statusClass = member.dead ? 'status-dead' : (isMemberUnderPk(member) ? 'status-pk' : 'status-ok');
        const pkDetails = member.targetName ? ` -> ${member.targetName}` : (member.pkAttackerNames ? ` ${member.pkAttackerNames}` : '');
        const leaderActive = isMemberMarkedLeader(member);
        const callerActive = isMemberMarkedCaller(member);

        row.innerHTML = `
            <td data-label="Character"><button class="map-link" type="button">${escapeHtml(member.name || '-')}</button></td>
            <td data-label="Channel">${escapeHtml(member.channel || '-')}</td>
            <td data-label="Level"><span class="level-badge" style="background-color: ${levelColor}">${escapeHtml(member.level || 0)}</span></td>
            <td data-label="Vocation"><span class="vocation-badge ${vocationClass}">${escapeHtml(vocationName)}</span></td>
            <td data-label="Status"><span class="status-badge ${statusClass}">${escapeHtml(statusLabel + pkDetails)}</span></td>
            <td data-label="Leader"><label class="role-check"><input type="checkbox" data-role-setting="leader" ${leaderActive ? 'checked' : ''}> Leader</label></td>
            <td data-label="Caller"><label class="role-check"><input type="checkbox" data-role-setting="caller" ${callerActive ? 'checked' : ''}> Caller</label></td>
            <td data-label="Location">${escapeHtml(guildCoords(member))}</td>
            <td data-label="Map">${escapeHtml(member.map || '-')}</td>
            <td data-label="Last Update">${escapeHtml(member.lastUpdate || 'Never')}</td>
        `;

        row.querySelector('.map-link').addEventListener('click', () => selectGuildLocation(member.name));
        row.querySelectorAll('[data-role-setting]').forEach(input => {
            input.addEventListener('click', event => event.stopPropagation());
            input.addEventListener('change', event => {
                setPlayerFlagFromLocations(member.name, event.target.dataset.roleSetting, event.target.checked);
            });
        });
        row.addEventListener('dblclick', () => selectGuildLocation(member.name));
        locationsBody.appendChild(row);
    });
}

function setGuildSettingsStatus(text, failed = false) {
    const status = document.getElementById('guild-settings-status');
    if (!status) return;
    status.textContent = text || '';
    status.classList.toggle('bad', failed);
}

function setPlayerFlagFromLocations(character, flag, active) {
    if (!character || !flag) return;
    const payload = { character };
    if (flag === 'leader') {
        payload.leader = Boolean(active);
        payload.highlighted = Boolean(active);
    } else if (flag === 'caller') {
        payload.caller = Boolean(active);
    } else {
        return;
    }

    setGuildSettingsStatus(`${character}: ${flag} ${active ? 'ON' : 'OFF'}...`);
    postJson('/api/player-settings', payload)
        .then(data => {
            tierOrbs = data.tierOrbs || tierOrbs;
            setGuildSettingsStatus(`${character}: ${flag} ${active ? 'ON' : 'OFF'}.`);
            fetchStats();
        })
        .catch(error => {
            setGuildSettingsStatus(error.message, true);
            fetchStats();
        });
}

function renderGuildMinimap() {
    const map = document.getElementById('guild-map');
    const image = document.getElementById('guild-map-image');
    const pins = document.getElementById('guild-map-pins');
    const focusText = document.getElementById('guild-map-focus');
    const countText = document.getElementById('guild-map-count');
    const floorText = document.getElementById('guild-map-floor');
    if (!map || !image || !pins || !focusText || !countText || !floorText) return;

    pins.innerHTML = '';
    countText.textContent = `${guildLocations.length} players`;

    if (!selectedGuildLocation) {
        image.removeAttribute('src');
        focusText.textContent = 'Sem localizacoes recebidas.';
        floorText.textContent = '-';
        return;
    }

    if (guildMapFollowSelected && selectedGuildLocation) {
        guildMapCenter = positionFrom(selectedGuildLocation);
        selectedGuildFloor = Number(selectedGuildLocation.z);
    }

    if (!guildMapCenter) {
        guildMapCenter = positionFrom(selectedGuildLocation);
    }

    if (!Number.isFinite(Number(selectedGuildFloor))) {
        selectedGuildFloor = Number(selectedGuildLocation.z);
    }

    const rect = map.getBoundingClientRect();
    const width = Math.round(rect.width);
    const height = Math.round(rect.height);
    if (width < 10 || height < 10) return;

    const centerX = Number(guildMapCenter?.x);
    const centerY = Number(guildMapCenter?.y);
    const viewFloor = Number(selectedGuildFloor);
    if (!Number.isFinite(centerX) || !Number.isFinite(centerY) || !Number.isFinite(viewFloor)) return;
    const src = `/api/minimap/view?x=${centerX}&y=${centerY}&z=${viewFloor}&w=${width}&h=${height}&scale=${guildMapZoom}`;
    if (image.dataset.src !== src) {
        image.dataset.src = src;
        image.src = src;
    }

    floorText.textContent = viewFloor;
    focusText.textContent = guildMapFollowSelected
        ? `Seguindo ${selectedGuildLocation.name} | ${guildCoords(selectedGuildLocation)} | zoom ${guildMapZoom}x`
        : `Mapa livre | centro ${Math.round(centerX)}, ${Math.round(centerY)}, ${viewFloor} | foco ${selectedGuildLocation.name} | zoom ${guildMapZoom}x`;

    const context = {
        width,
        height,
        centerX,
        centerY,
        viewFloor
    };

    guildLocations.forEach(member => {
        if (Number(member.z) !== viewFloor) return;
        if (member.dead) return;

        const dx = (Number(member.x) - centerX) * guildMapZoom;
        const dy = (Number(member.y) - centerY) * guildMapZoom;
        const left = width / 2 + dx;
        const top = height / 2 + dy;
        if (left < -40 || left > width + 40 || top < -20 || top > height + 20) return;

        const pin = document.createElement('button');
        pin.type = 'button';
        pin.className = `guild-map-pin ${getVocationClass(member.vocationKey || member.vocation)}`;
        if (member.name === selectedGuildLocation.name) pin.classList.add('selected');
        if (isMemberUnderPk(member)) pin.classList.add('pk-alert');
        if (isMemberMarkedLeader(member)) pin.classList.add('leader-mark');
        if (member.dead) pin.classList.add('dead');
        pin.style.left = `${left}px`;
        pin.style.top = `${top}px`;
        pin.title = `${member.name} | ${guildCoords(member)} | ${guildDistance(member, selectedGuildLocation)}${isMemberUnderPk(member) ? ' | PK alert' : ''}${isMemberMarkedLeader(member) ? ' | Leader' : ''}`;
        pin.innerHTML = `
            <span>${escapeHtml(member.name || '?')}</span>
            ${isMemberUnderPk(member) ? '<b class="pk-skull" aria-hidden="true">PK</b>' : ''}
        `;
        pin.addEventListener('click', () => selectGuildLocation(member.name));
        pins.appendChild(pin);
    });

    renderWolfMapLayers(pins, context);
}

window.selectGuildLocation = selectGuildLocation;

function positionFrom(value) {
    if (!value) return null;
    const pos = value.position || value;
    const x = Number(pos.x);
    const y = Number(pos.y);
    const z = Number(pos.z);
    if (!Number.isFinite(x) || !Number.isFinite(y) || !Number.isFinite(z)) return null;
    return { x, y, z };
}

function deathInRange(death) {
    if (!death || wolfHeatmapRange === 'all') return true;
    const at = Number(death.at) || 0;
    if (!at) return true;
    const age = Date.now() - at;
    if (wolfHeatmapRange === 'today') {
        return new Date(at).toDateString() === new Date().toDateString();
    }
    const days = Number(wolfHeatmapRange);
    if (!Number.isFinite(days)) return true;
    return age <= days * 24 * 60 * 60 * 1000;
}

function heatBucketValue(value) {
    const size = WOLF_HEATMAP_BUCKET_SIZE;
    return Math.floor(Number(value) / size) * size;
}

function heatBucketCenter(value) {
    return heatBucketValue(value) + Math.floor(WOLF_HEATMAP_BUCKET_SIZE / 2);
}

function heatmapPointFromDeath(death) {
    const real = positionFrom(death);
    if (!real) return null;

    const bucketX = heatBucketValue(real.x);
    const bucketY = heatBucketValue(real.y);
    const z = wolfHeatmapRegional
        ? (wolfHeatmapProjectZ7 ? WOLF_HEATMAP_FLOOR : real.z)
        : (wolfHeatmapByFloor ? real.z : (wolfHeatmapProjectZ7 ? WOLF_HEATMAP_FLOOR : real.z));
    const key = [
        bucketX,
        bucketY,
        wolfHeatmapByFloor && !wolfHeatmapRegional ? real.z : 'regional'
    ].join(',');

    return {
        key,
        real,
        display: {
            x: heatBucketCenter(real.x),
            y: heatBucketCenter(real.y),
            z
        },
        bucket: {
            x1: bucketX,
            y1: bucketY,
            x2: bucketX + WOLF_HEATMAP_BUCKET_SIZE - 1,
            y2: bucketY + WOLF_HEATMAP_BUCKET_SIZE - 1
        }
    };
}

function heatmapTitle(item) {
    const floors = Array.from(new Set(item.realPositions.map(pos => pos.z))).sort((a, b) => a - b);
    const latest = item.events
        .map(event => ({ event, at: Number(event.at) || 0 }))
        .sort((a, b) => b.at - a.at)[0]?.event;
    const latestText = latest ? ` | Ultima ${latest.day || ''} ${latest.time || ''}` : '';
    return `Ponto quente Exalted Wolf | Centro ${item.pos.x}, ${item.pos.y} | Mortes ${item.count} | Andares reais: ${floors.join(', ')} | Orbs: ${item.orbs}${latestText}`;
}

function showHeatmapDetails(item) {
    const floors = Array.from(new Set(item.realPositions.map(pos => pos.z))).sort((a, b) => a - b);
    const lines = [
        `Ponto quente Exalted Wolf`,
        `Centro: ${item.pos.x}, ${item.pos.y}, ${item.pos.z}`,
        `Mortes: ${item.count}`,
        `Orbs: ${item.orbs}`,
        `Andares reais: ${floors.join(', ')}`,
        ''
    ];
    item.events
        .slice()
        .sort((a, b) => (Number(b.at) || 0) - (Number(a.at) || 0))
        .slice(0, 12)
        .forEach(event => {
            const pos = positionFrom(event);
            lines.push(`${event.day || ''} ${event.time || ''} | ${pos ? guildCoords(pos) : '-'} | ${event.orbs || 0} orbs`);
        });
    window.alert(lines.join('\n'));
}

function mapLayerPosition(pos, context) {
    if (!pos || Number(pos.z) !== Number(context.viewFloor)) return null;
    const left = context.width / 2 + (Number(pos.x) - context.centerX) * guildMapZoom;
    const top = context.height / 2 + (Number(pos.y) - context.centerY) * guildMapZoom;
    if (left < -80 || left > context.width + 80 || top < -80 || top > context.height + 80) return null;
    return { left, top };
}

function renderWolfMapLayers(pins, context) {
    if (!tierOrbs) return;

    const deaths = (tierOrbs.deaths || []).filter(deathInRange);
    if (showWolfHeatmap) {
        const heat = new Map();
        deaths.forEach(death => {
            const projected = heatmapPointFromDeath(death);
            if (!projected || Number(projected.display.z) !== Number(context.viewFloor)) return;
            const item = heat.get(projected.key) || {
                pos: projected.display,
                bucket: projected.bucket,
                realPositions: [],
                events: [],
                count: 0,
                orbs: 0
            };
            item.count += 1;
            item.orbs += Number(death.orbs) || 0;
            item.realPositions.push(projected.real);
            item.events.push(death);
            heat.set(projected.key, item);
        });

        const maxCount = Math.max(1, ...Array.from(heat.values()).map(item => item.count));
        heat.forEach(item => {
            const point = mapLayerPosition(item.pos, context);
            if (!point) return;
            const node = document.createElement('button');
            node.type = 'button';
            node.className = 'wolf-heat-point';
            const size = 22 + Math.round((item.count / maxCount) * 42);
            node.style.width = `${size}px`;
            node.style.height = `${size}px`;
            node.style.left = `${point.left}px`;
            node.style.top = `${point.top}px`;
            node.title = heatmapTitle(item);
            node.addEventListener('click', event => {
                event.stopPropagation();
                showHeatmapDetails(item);
            });
            pins.appendChild(node);
        });
    }

    if (showWolfDeaths) {
        deaths.forEach(death => {
            const pos = positionFrom(death);
            const point = mapLayerPosition(pos, context);
            if (!point) return;
            const pin = document.createElement('button');
            pin.type = 'button';
            pin.className = 'wolf-death-pin';
            pin.style.left = `${point.left}px`;
            pin.style.top = `${point.top}px`;
            pin.title = `Exalted Wolf | ${death.day} ${death.time} | ${death.location || guildCoords(pos)} | ${death.orbs || 0} orbs | ${death.uniqueReceivers || 0} cotas | credito ${formatCredit(death.creditPerReceiver ?? death.share ?? 0)} | sobra tecnica ${death.technicalRemainder ?? death.remainder ?? 0}`;
            pin.innerHTML = '<span>W</span>';
            pins.appendChild(pin);
        });
    }
}

function statusBadge(value, yesText = 'Yes', noText = 'No', danger = false) {
    const className = value ? (danger ? 'bad' : 'on') : 'off';
    return `<span class="status-badge ${className}">${value ? yesText : noText}</span>`;
}

function renderTierOrbs() {
    if (!tierOrbs) return;

    const participants = tierOrbs.participants || [];
    const totals = tierOrbs.totals || {};
    const collection = tierOrbs.collection || null;
    setText('tier-detected', tierOrbs.onlineCount ?? participants.filter(participant => participant.online).length);
    setText('tier-eligible', tierOrbs.eligibleCount || 0);
    setText('tier-receivers', tierOrbs.uniqueReceivers || 0);
    setText('tier-orbs-today', totals.orbsToday || 0);
    setText('tier-total', totals.wholeOrbsToPay ?? totals.totalOrbs ?? 0);
    setText('tier-leftovers', totals.technicalLeftover ?? totals.leftoversTotal ?? 0);
    setText(
        'tier-collection-status',
        collection?.startedAt
            ? `Coleta atual: ${collection.startedAtText || '-'} por ${collection.startedBy || 'BotServer'}`
            : 'Coleta atual: historico anterior. Clique em iniciar para abrir uma nova instancia.'
    );

    const eventAreas = document.getElementById('tier-event-areas');
    const depotAreas = document.getElementById('tier-depot-areas');
    if (eventAreas && document.activeElement !== eventAreas) eventAreas.value = tierOrbs.settings?.eventAreasText || '';
    if (depotAreas && document.activeElement !== depotAreas) depotAreas.value = tierOrbs.settings?.depotAreasText || '';

    renderTierSplitSummary(tierOrbs.receivers || []);
    renderTierCharacters(participants);
    renderTierReceivers(tierOrbs.receivers || []);
    renderTierOrbReports(tierOrbs.orbReports || []);
    renderTierHistory(tierOrbs.days || []);
    renderTierDeaths(tierOrbs.deaths || []);
}

function setText(id, value) {
    const node = document.getElementById(id);
    if (node) node.textContent = value;
}

function renderTierSplitSummary(receivers) {
    const body = document.getElementById('tier-split-body');
    const note = document.getElementById('tier-split-note');
    if (!body) return;
    body.innerHTML = '';

    const latestDeath = tierOrbs?.totals?.latestDeath || null;
    const latestRows = new Map((latestDeath?.receivers || []).map(row => [row.receiver, row]));
    const activeGroups = (receivers || []).filter(receiver =>
        Number(receiver.currentShare) > 0 ||
        Number(receiver.totalToday) > 0 ||
        Number(receiver.totalCredit) > 0 ||
        Number(receiver.total) > 0 ||
        Number(receiver.characterCount) > 0
    );

    if (note) {
        const latestText = latestDeath
            ? `Ultimo drop: ${latestDeath.orbs || 0} orbs em ${latestDeath.location || '-'}; credito ${formatCredit(latestDeath.creditPerReceiver ?? latestDeath.share ?? 0)} por recebedor; sobra tecnica ${formatNumber(latestDeath.technicalRemainder ?? latestDeath.remainder ?? 0)}.`
            : 'Ainda sem drop registrado.';
        note.textContent = `Cada grupo ativo conta como 1 cota. ${latestText}`;
    }

    if (!activeGroups.length) {
        body.innerHTML = '<tr><td colspan="8">Nenhum recebedor com cota ou historico.</td></tr>';
        return;
    }

    activeGroups
        .sort((a, b) => String(a.receiver || '').localeCompare(String(b.receiver || '')))
        .forEach(receiver => {
            const latest = latestRows.get(receiver.receiver);
            const characters = receiver.characters?.length
                ? receiver.characters.join(', ')
                : '-';
            const eligibleCharacters = receiver.eligibleCharacters?.length
                ? receiver.eligibleCharacters.join(', ')
                : '-';
            const latestCredit = latest
                ? (latest.credit ?? latest.creditPerReceiver ?? latest.share ?? 0)
                : (receiver.latestCredit || 0);
            const row = document.createElement('tr');
            row.innerHTML = `
                <td data-label="Recebedor"><strong>${escapeHtml(receiver.receiver || '-')}</strong></td>
                <td data-label="Personagens vinculados">${escapeHtml(characters)}</td>
                <td data-label="Elegíveis agora">${escapeHtml(eligibleCharacters)}</td>
                <td data-label="Cota ativa">${Number(receiver.currentShare) > 0 ? '1 cota' : 'Sem cota'}</td>
                <td data-label="Crédito do último drop">${latest ? formatCredit(latestCredit) : '-'}</td>
                <td data-label="Crédito acumulado hoje">${formatCredit(receiver.todayCredit ?? receiver.totalToday ?? 0)}</td>
                <td data-label="Orbs inteiras a receber">${formatNumber(receiver.wholeOrbs ?? receiver.total ?? 0)}</td>
                <td data-label="Saldo decimal">${formatCredit(receiver.decimalBalance ?? 0)}</td>
            `;
            body.appendChild(row);
        });
}

function renderTierCharacters(participants) {
    const list = document.getElementById('tier-character-list');
    if (!list) return;
    list.innerHTML = '';

    const filter = normalizeSearch(document.getElementById('tier-character-search')?.value);
    const rows = participants
        .filter(participant => !filter || normalizeSearch(participant.name).includes(filter))
        .sort((a, b) => String(a.name || '').localeCompare(String(b.name || '')));

    if (!rows.length) {
        list.innerHTML = '<div class="tier-empty">Nenhum personagem encontrado.</div>';
        return;
    }

    rows.forEach(participant => {
        const card = document.createElement('div');
        card.className = `tier-character-card${participant.eligible ? ' eligible' : ''}`;
        card.draggable = true;
        card.dataset.character = participant.name || '';
        card.addEventListener('dragstart', event => {
            event.dataTransfer.setData('text/plain', participant.name || '');
            event.dataTransfer.effectAllowed = 'move';
            card.classList.add('dragging');
        });
        card.addEventListener('dragend', () => card.classList.remove('dragging'));

        const receiver = participant.receiver && participant.receiver !== participant.name
            ? participant.receiver
            : 'Proprio nome';

        card.innerHTML = `
            <div class="tier-character-main">
                <strong>${escapeHtml(participant.name || '-')}</strong>
                <span>${escapeHtml(receiver)}</span>
            </div>
            <div class="tier-character-meta">
                ${statusBadge(participant.scout, 'Scout', '-')}
                ${statusBadge(participant.killer, 'Killer', '-')}
                ${statusBadge(participant.eligible, 'Elegivel', 'Fora')}
            </div>
            <div class="tier-character-reason">${escapeHtml(participant.reason || participant.location || '-')}</div>
        `;
        list.appendChild(card);
    });
}

function renderTierReceivers(receivers) {
    const list = document.getElementById('tier-group-list');
    if (!list) return;
    list.innerHTML = '';

    const filter = normalizeSearch(document.getElementById('tier-receiver-search')?.value);
    const rows = receivers
        .filter(receiver => !filter || normalizeSearch(receiver.receiver).includes(filter))
        .sort((a, b) => String(a.receiver || '').localeCompare(String(b.receiver || '')));

    if (!rows.length) {
        list.innerHTML = '<div class="tier-empty">Nenhum grupo de recebedor.</div>';
        return;
    }

    rows.forEach(receiver => {
        const group = document.createElement('div');
        const hasShare = Number(receiver.currentShare) > 0;
        group.className = `tier-receiver-card${hasShare ? ' active' : ''}`;
        group.dataset.receiver = receiver.receiver || '';

        group.addEventListener('dragover', event => {
            event.preventDefault();
            event.dataTransfer.dropEffect = 'move';
            group.classList.add('drag-over');
        });
        group.addEventListener('dragleave', () => group.classList.remove('drag-over'));
        group.addEventListener('drop', event => {
            event.preventDefault();
            group.classList.remove('drag-over');
            const character = event.dataTransfer.getData('text/plain');
            if (character) assignTierReceiver(character, receiver.receiver);
        });

        const members = (receiver.characters || []).map(character => `
            <div class="tier-group-member" draggable="true" data-character="${escapeHtml(character)}">
                <span>${escapeHtml(character)}</span>
                <button type="button" class="tier-member-remove" data-character="${escapeHtml(character)}" title="Remover do grupo">x</button>
            </div>
        `).join('');

        group.innerHTML = `
            <div class="tier-receiver-head">
                <div>
                    <h4>${escapeHtml(receiver.receiver || '-')}</h4>
                    <span>${formatNumber(receiver.characterCount || 0)} personagens | este grupo conta como 1 cota</span>
                </div>
                <div class="tier-receiver-actions">
                    <button type="button" data-action="rename" data-receiver="${escapeHtml(receiver.receiver || '')}">Renomear recebedor</button>
                    <button type="button" data-action="remove-group" data-receiver="${escapeHtml(receiver.receiver || '')}">Remover grupo</button>
                </div>
            </div>
            <div class="tier-receiver-stats">
                ${statusBadge(hasShare, '1 cota', 'Sem cota')}
                <span>Elegiveis: ${formatNumber(receiver.eligibleCount || 0)}</span>
                <span>Credito hoje: ${formatCredit(receiver.todayCredit ?? receiver.totalToday ?? 0)}</span>
                <span>Inteiras: ${formatNumber(receiver.wholeOrbs ?? receiver.total ?? 0)}</span>
                <span>Saldo: ${formatCredit(receiver.decimalBalance ?? 0)}</span>
            </div>
            <div class="tier-group-members">${members || '<div class="tier-drop-hint">Solte personagens aqui.</div>'}</div>
        `;

        group.querySelectorAll('.tier-group-member').forEach(member => {
            member.addEventListener('dragstart', event => {
                event.dataTransfer.setData('text/plain', member.dataset.character || '');
                event.dataTransfer.effectAllowed = 'move';
                member.classList.add('dragging');
            });
            member.addEventListener('dragend', () => member.classList.remove('dragging'));
        });

        group.querySelectorAll('[data-action="rename"]').forEach(button => {
            button.addEventListener('click', () => renameTierGroup(button.dataset.receiver));
        });
        group.querySelectorAll('[data-action="remove-group"]').forEach(button => {
            button.addEventListener('click', () => removeTierGroup(button.dataset.receiver));
        });
        group.querySelectorAll('.tier-member-remove').forEach(button => {
            button.addEventListener('click', () => removeTierReceiver(button.dataset.character));
        });

        list.appendChild(group);
    });
}

function normalizeSearch(value) {
    return String(value || '').trim().toLowerCase();
}

function setTierGroupStatus(text, failed = false) {
    const status = document.getElementById('tier-group-status');
    if (!status) return;
    status.textContent = text || '';
    status.classList.toggle('bad', failed);
}

function isDashboardAdmin() {
    return authUser && authUser.role === 'admin';
}

function setAccessStatus(text, failed = false) {
    const status = document.getElementById('access-status');
    if (!status) return;
    status.textContent = text || '';
    status.style.color = failed ? '#9a2f2f' : '#5f6b7a';
}

function updateAccessVisibility() {
    const current = document.getElementById('access-current-user');
    const panel = document.getElementById('access-admin-panel');
    const noAdmin = document.getElementById('access-no-admin');
    if (current) {
        current.textContent = authUser
            ? `Logado como ${authUser.username} (${authUser.role})`
            : 'Sessao nao identificada';
    }
    if (panel) panel.style.display = isDashboardAdmin() ? '' : 'none';
    if (noAdmin) noAdmin.style.display = isDashboardAdmin() ? 'none' : 'block';
}

function formatAccessDate(value) {
    const date = Number(value);
    return date ? new Date(date).toLocaleString() : '-';
}

function renderDashboardUsers() {
    updateAccessVisibility();
    const body = document.getElementById('access-users-body');
    if (!body) return;
    body.innerHTML = '';

    dashboardUsers.forEach(user => {
        const protectedUser = Boolean(user.protected);
        const active = user.active !== false;
        const role = user.role === 'admin' ? 'admin' : 'user';
        const row = document.createElement('tr');
        row.innerHTML = `
            <td data-label="Usuario"><strong>${escapeHtml(user.username)}</strong></td>
            <td data-label="Tipo"><span class="access-badge">${escapeHtml(role)}</span></td>
            <td data-label="Status"><span class="access-badge ${active ? 'active' : 'inactive'}">${active ? 'Ativo' : 'Inativo'}</span></td>
            <td data-label="Origem">${protectedUser ? 'config' : 'cadastro'}</td>
            <td data-label="Ultimo login">${escapeHtml(formatAccessDate(user.lastLoginAt))}</td>
            <td data-label="Acoes">
                <div class="access-actions">
                    <button type="button" class="access-action secondary" data-action="password" data-user="${escapeHtml(user.username)}" ${protectedUser ? 'disabled' : ''}>Senha</button>
                    <button type="button" class="access-action secondary" data-action="role" data-user="${escapeHtml(user.username)}" data-role="${role}" ${protectedUser ? 'disabled' : ''}>${role === 'admin' ? 'Virar user' : 'Virar admin'}</button>
                    <button type="button" class="access-action secondary" data-action="active" data-user="${escapeHtml(user.username)}" data-active="${active}" ${protectedUser ? 'disabled' : ''}>${active ? 'Desativar' : 'Ativar'}</button>
                    <button type="button" class="access-action danger" data-action="delete" data-user="${escapeHtml(user.username)}" ${protectedUser ? 'disabled' : ''}>Remover</button>
                </div>
            </td>
        `;

        row.querySelectorAll('[data-action]').forEach(button => {
            button.addEventListener('click', () => handleAccessAction(button));
        });
        body.appendChild(row);
    });
}

function fetchDashboardUsers() {
    updateAccessVisibility();
    if (!isDashboardAdmin()) return;
    setAccessStatus('Carregando acessos...');
    requestJson('/api/dashboard-users')
        .then(data => {
            dashboardUsers = data.users || [];
            renderDashboardUsers();
            setAccessStatus(`${dashboardUsers.length} acesso(s) carregado(s).`);
        })
        .catch(error => setAccessStatus(error.message, true));
}

function createDashboardUser() {
    if (!isDashboardAdmin()) return;
    const usernameInput = document.getElementById('access-username');
    const passwordInput = document.getElementById('access-password');
    const roleInput = document.getElementById('access-role');
    const activeInput = document.getElementById('access-active');
    const username = usernameInput?.value.trim() || '';
    const password = passwordInput?.value || '';
    const role = roleInput?.value || 'user';
    const active = activeInput ? activeInput.checked : true;

    setAccessStatus(`Cadastrando ${username}...`);
    postJson('/api/dashboard-users', { username, password, role, active })
        .then(data => {
            dashboardUsers = data.users || [];
            if (usernameInput) usernameInput.value = '';
            if (passwordInput) passwordInput.value = '';
            renderDashboardUsers();
            setAccessStatus(`Usuario ${username} cadastrado.`);
        })
        .catch(error => setAccessStatus(error.message, true));
}

function handleAccessAction(button) {
    const username = button.dataset.user;
    const action = button.dataset.action;
    if (!username || !action) return;

    if (action === 'password') {
        const password = window.prompt(`Nova senha para ${username}`);
        if (!password) return;
        setAccessStatus(`Atualizando senha de ${username}...`);
        patchJson(`/api/dashboard-users/${encodeURIComponent(username)}`, { password })
            .then(data => {
                dashboardUsers = data.users || [];
                renderDashboardUsers();
                setAccessStatus(`Senha de ${username} atualizada.`);
            })
            .catch(error => setAccessStatus(error.message, true));
        return;
    }

    if (action === 'role') {
        const nextRole = button.dataset.role === 'admin' ? 'user' : 'admin';
        setAccessStatus(`Alterando permissao de ${username}...`);
        patchJson(`/api/dashboard-users/${encodeURIComponent(username)}`, { role: nextRole })
            .then(data => {
                dashboardUsers = data.users || [];
                renderDashboardUsers();
                setAccessStatus(`${username} agora e ${nextRole}.`);
            })
            .catch(error => setAccessStatus(error.message, true));
        return;
    }

    if (action === 'active') {
        const active = button.dataset.active !== 'true';
        setAccessStatus(`${active ? 'Ativando' : 'Desativando'} ${username}...`);
        patchJson(`/api/dashboard-users/${encodeURIComponent(username)}`, { active })
            .then(data => {
                dashboardUsers = data.users || [];
                renderDashboardUsers();
                setAccessStatus(`${username} ${active ? 'ativado' : 'desativado'}.`);
            })
            .catch(error => setAccessStatus(error.message, true));
        return;
    }

    if (action === 'delete') {
        if (!window.confirm(`Remover acesso de ${username}?`)) return;
        setAccessStatus(`Removendo ${username}...`);
        requestJson(`/api/dashboard-users/${encodeURIComponent(username)}`, { method: 'DELETE' })
            .then(data => {
                dashboardUsers = data.users || [];
                renderDashboardUsers();
                setAccessStatus(`Acesso de ${username} removido.`);
            })
            .catch(error => setAccessStatus(error.message, true));
    }
}

function applyTierResponse(data, message) {
    tierOrbs = data.tierOrbs || tierOrbs;
    renderTierOrbs();
    if (message) setTierGroupStatus(message);
}

function startTierCollection() {
    setTierGroupStatus('Iniciando nova coleta de Tier Orb...');
    postJson('/api/tier-orbs/start', { startedBy: 'Dashboard' })
        .then(data => applyTierResponse(data, 'Nova coleta de Tier Orb iniciada.'))
        .catch(error => setTierGroupStatus(error.message, true));
}

function assignTierReceiver(character, receiver) {
    setTierGroupStatus(`Salvando ${character} -> ${receiver}...`);
    postJson('/api/tier-orbs/receiver', { character, receiver })
        .then(data => applyTierResponse(data, `${character} vinculado a ${receiver}.`))
        .catch(error => setTierGroupStatus(error.message, true));
}

function removeTierReceiver(character) {
    setTierGroupStatus(`Removendo ${character} do grupo...`);
    fetch(`/api/tier-orbs/receiver/${encodeURIComponent(character)}`, { method: 'DELETE' })
        .then(async response => {
            const body = await response.json().catch(() => ({}));
            if (!response.ok || body.ok === false) throw new Error(body.error || response.statusText);
            return body;
        })
        .then(data => applyTierResponse(data, `${character} agora recebe no proprio nome.`))
        .catch(error => setTierGroupStatus(error.message, true));
}

function createTierGroup() {
    const receiver = window.prompt('Nome do recebedor');
    if (!receiver || !receiver.trim()) return;
    setTierGroupStatus(`Criando ${receiver.trim()}...`);
    postJson('/api/tier-orbs/groups', { receiver: receiver.trim() })
        .then(data => applyTierResponse(data, `Recebedor ${data.receiver} criado.`))
        .catch(error => setTierGroupStatus(error.message, true));
}

function renameTierGroup(receiver) {
    const nextName = window.prompt('Novo nome do recebedor', receiver || '');
    if (!nextName || !nextName.trim() || nextName.trim() === receiver) return;
    setTierGroupStatus(`Renomeando ${receiver}...`);
    fetch(`/api/tier-orbs/groups/${encodeURIComponent(receiver)}`, {
        method: 'PATCH',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ receiver: nextName.trim() })
    })
        .then(async response => {
            const body = await response.json().catch(() => ({}));
            if (!response.ok || body.ok === false) throw new Error(body.error || response.statusText);
            return body;
        })
        .then(data => applyTierResponse(data, `Recebedor renomeado para ${data.receiver}.`))
        .catch(error => setTierGroupStatus(error.message, true));
}

function removeTierGroup(receiver) {
    if (!receiver) return;
    if (!window.confirm(`Remover o grupo "${receiver}"? Os personagens voltam a receber no proprio nome.`)) return;
    setTierGroupStatus(`Removendo ${receiver}...`);
    fetch(`/api/tier-orbs/groups/${encodeURIComponent(receiver)}`, { method: 'DELETE' })
        .then(async response => {
            const body = await response.json().catch(() => ({}));
            if (!response.ok || body.ok === false) throw new Error(body.error || response.statusText);
            return body;
        })
        .then(data => applyTierResponse(data, `Recebedor ${data.receiver} removido.`))
        .catch(error => setTierGroupStatus(error.message, true));
}

function renderTierOrbReports(reports) {
    const body = document.getElementById('tier-orb-reports-body');
    const status = document.getElementById('tier-auto-status');
    if (!body) return;
    body.innerHTML = '';

    if (status) {
        const latest = reports
            .filter(report => Number(report.lastUpdateMs))
            .sort((a, b) => Number(b.lastUpdateMs) - Number(a.lastUpdateMs))[0];
        status.textContent = latest
            ? `Last report: ${latest.name} has ${latest.count || 0} Tier Orbs.`
            : 'Waiting for reports...';
    }

    reports.forEach(report => {
        const row = document.createElement('tr');
        const role = report.scoutActive ? 'Scout' : (report.killerActive ? 'Killer' : '-');
        const lastDelta = Number(report.lastDrop || report.delta || 0);
        row.innerHTML = `
            <td data-label="Character">${escapeHtml(report.name || '-')}</td>
            <td data-label="Tier Orbs">${formatNumber(report.count || 0)}</td>
            <td data-label="Last Delta">${lastDelta > 0 ? '+' + formatNumber(lastDelta) : '-'}</td>
            <td data-label="Role">${escapeHtml(role)}</td>
            <td data-label="Position">${escapeHtml(report.location || '-')}</td>
            <td data-label="Reason">${escapeHtml(report.reason || '-')}</td>
            <td data-label="Last Update">${escapeHtml(report.lastUpdate || '-')}</td>
            <td data-label="Status">${escapeHtml(report.lastError || 'OK')}</td>
        `;
        body.appendChild(row);
    });
}

function renderTierHistory(days) {
    const wrap = document.getElementById('tier-history');
    if (!wrap) return;
    wrap.innerHTML = '';

    days.slice(0, 7).forEach(day => {
        const box = document.createElement('div');
        box.className = 'tier-day';
        const events = (day.events || []).slice(0, 60).map(event =>
            `<li><strong>${escapeHtml(event.time || '')}</strong> ${escapeHtml(event.text || '')}</li>`
        ).join('');
        box.innerHTML = `<h4>${escapeHtml(day.day)}</h4><ul>${events || '<li>No events</li>'}</ul>`;
        wrap.appendChild(box);
    });
}

function renderTierDeaths(deaths) {
    const body = document.getElementById('tier-deaths-body');
    if (!body) return;
    body.innerHTML = '';

    deaths.slice(0, 60).forEach(death => {
        const row = document.createElement('tr');
        row.innerHTML = `
            <td data-label="Time">${escapeHtml(`${death.day || ''} ${death.time || ''}`)}</td>
            <td data-label="Position">${escapeHtml(death.location || '-')}</td>
            <td data-label="Orbs">${formatNumber(death.orbs || 0)}</td>
            <td data-label="Personagens elegíveis">${death.eligibleCount || 0}</td>
            <td data-label="Cotas">${death.uniqueReceivers || 0}</td>
            <td data-label="Crédito por recebedor">${formatCredit(death.creditPerReceiver ?? death.share ?? 0)}</td>
            <td data-label="Sobra técnica">${formatNumber(death.technicalRemainder ?? death.remainder ?? 0)}</td>
        `;
        body.appendChild(row);
    });
}

function requestJson(url, options = {}) {
    return fetch(url, {
        ...options,
        headers: {
            ...(options.body ? { 'Content-Type': 'application/json' } : {}),
            ...(options.headers || {})
        }
    }).then(async response => {
        if (response.status === 401) {
            window.location.href = '/login';
            throw new Error('Login required');
        }
        const body = await response.json().catch(() => ({}));
        if (!response.ok || body.ok === false) throw new Error(body.error || response.statusText);
        return body;
    });
}

function postJson(url, data) {
    return requestJson(url, {
        method: 'POST',
        body: JSON.stringify(data)
    });
}

function patchJson(url, data) {
    return requestJson(url, {
        method: 'PATCH',
        body: JSON.stringify(data)
    });
}

function navDebugPositionText(payload) {
    if (!payload || typeof payload !== 'object') return '-';
    const pos = positionFrom(payload.position) || positionFrom(payload);
    if (pos) return guildCoords(pos);
    return payload.location || '-';
}

function renderNavDebugScouts() {
    const select = document.getElementById('nav-debug-scout');
    if (!select) return;
    const previous = select.value;
    select.innerHTML = '';

    if (!navDebugScouts.length) {
        const option = document.createElement('option');
        option.value = '';
        option.textContent = 'Nenhum Scout ativo';
        select.appendChild(option);
        select.disabled = true;
        return;
    }

    select.disabled = false;
    navDebugScouts.forEach(scout => {
        const option = document.createElement('option');
        option.value = scout.name;
        option.textContent = `${scout.name} | ${scout.location || guildCoords(scout)}`;
        select.appendChild(option);
    });

    if (previous && navDebugScouts.some(scout => scout.name === previous)) {
        select.value = previous;
    }
}

function renderNavDebugEvents() {
    const body = document.getElementById('nav-debug-body');
    const status = document.getElementById('nav-debug-status');
    if (!body || !status) return;

    status.textContent = `${navDebugScouts.length} Scouts ativos | ${navDebugEvents.length} eventos`;
    body.innerHTML = '';

    navDebugEvents.forEach(event => {
        const payload = event.message || {};
        const receivers = Array.isArray(event.receivers) ? event.receivers.filter(Boolean) : [];
        const receiversText = receivers.length > 5
            ? `${receivers.slice(0, 5).join(', ')} +${receivers.length - 5}`
            : (receivers.join(', ') || '-');
        const statusText = payload.status
            ? `${payload.status}${event.status ? ` (${event.status})` : ''}`
            : (event.status || '-');
        const row = document.createElement('tr');
        if (event.direction === 'test') row.classList.add('nav-debug-test-row');
        row.innerHTML = `
            <td data-label="Hora">${escapeHtml(event.time || '-')}</td>
            <td data-label="Tipo">${escapeHtml(event.direction || '-')}</td>
            <td data-label="Topico">${escapeHtml(event.topic || '-')}</td>
            <td data-label="Canal">${escapeHtml(event.channel || '-')}</td>
            <td data-label="Remetente">${escapeHtml(event.sender || '-')}</td>
            <td data-label="Coordenada">${escapeHtml(navDebugPositionText(payload))}</td>
            <td data-label="Recebedores" title="${escapeHtml(receivers.join(', '))}">${escapeHtml(receiversText)}</td>
            <td data-label="Status">${escapeHtml(statusText)}</td>
        `;
        body.appendChild(row);
    });
}

function fetchNavDebug() {
    return requestJson('/api/nav-debug')
        .then(data => {
            navDebugScouts = Array.isArray(data.scouts) ? data.scouts : [];
            navDebugEvents = Array.isArray(data.events) ? data.events : [];
            renderNavDebugScouts();
            renderNavDebugEvents();
        })
        .catch(error => {
            const status = document.getElementById('nav-debug-status');
            if (status) status.textContent = error.message;
        });
}

function simulateNavCoordinate() {
    const select = document.getElementById('nav-debug-scout');
    const character = select?.value;
    const status = document.getElementById('nav-debug-status');
    if (!character) {
        if (status) status.textContent = 'Selecione um Scout ativo.';
        return;
    }

    if (status) status.textContent = `Simulando coordenada por ${character}...`;
    postJson('/api/nav-debug/simulate', { character })
        .then(data => {
            const count = Array.isArray(data.receivers) ? data.receivers.length : 0;
            if (status) status.textContent = `Coordenada simulada por ${character}. Recebedores: ${count}.`;
            fetchNavDebug();
        })
        .catch(error => {
            if (status) status.textContent = error.message;
        });
}

function saveTierSettings() {
    const status = document.getElementById('tier-settings-status');
    const eventAreasText = document.getElementById('tier-event-areas').value;
    const depotAreasText = document.getElementById('tier-depot-areas').value;
    if (status) status.textContent = 'Saving...';

    postJson('/api/tier-orbs/settings', { eventAreasText, depotAreasText })
        .then(data => {
            tierOrbs = data.tierOrbs;
            renderTierOrbs();
            if (status) status.textContent = 'Areas saved';
        })
        .catch(error => {
            if (status) status.textContent = error.message;
        });
}

function getLevelColor(level) {
    const levelNum = parseInt(level) || 0;
    if (levelNum < 50) return '#3498db'; 
    if (levelNum < 100) return '#2ecc71';
    if (levelNum < 200) return '#f39c12';
    return '#e74c3c';
}

function getVocationName(vocId) {
    const value = String(vocId ?? '').trim().toLowerCase();
    if (['1', '5', '13', 'sorcerer', 'ms', 'master sorcerer'].includes(value)) return 'Sorcerer';
    if (['2', '6', '14', 'druid', 'ed', 'elder druid'].includes(value)) return 'Druid';
    if (['3', '7', '12', 'paladin', 'rp', 'royal paladin'].includes(value)) return 'Paladin';
    if (['4', '8', '11', 'knight', 'ek', 'elite knight'].includes(value)) return 'Knight';
    return 'None';
}

function getVocationClass(vocId) {
    const value = String(vocId ?? '').trim().toLowerCase();
    if (['1', '5', '13', 'sorcerer', 'ms', 'master sorcerer'].includes(value)) return 'vocation-sorcerer';
    if (['2', '6', '14', 'druid', 'ed', 'elder druid'].includes(value)) return 'vocation-druid';
    if (['3', '7', '12', 'paladin', 'rp', 'royal paladin'].includes(value)) return 'vocation-paladin';
    if (['4', '8', '11', 'knight', 'ek', 'elite knight'].includes(value)) return 'vocation-knight';
    return 'vocation-none';
}

function formatNumber(num) {
    return new Intl.NumberFormat().format(num);
}

function formatCredit(num) {
    const value = Number(num);
    if (!Number.isFinite(value)) return '0';
    return new Intl.NumberFormat(undefined, {
        minimumFractionDigits: value % 1 === 0 ? 0 : 4,
        maximumFractionDigits: 4
    }).format(value);
}

let refreshInterval = null;

function setupRefresh() {
    clearInterval(refreshInterval);

    const enabled = document.getElementById('auto-refresh-toggle').checked;
    const seconds = Math.max(1, parseInt(document.getElementById('refresh-interval').value) || 1);

    if (enabled) {
        refreshInterval = setInterval(fetchStats, seconds * 1000);
    }
}

window.addEventListener('DOMContentLoaded', () => {
    const floorUp = document.getElementById('guild-map-floor-up');
    const floorDown = document.getElementById('guild-map-floor-down');
    if (floorUp) floorUp.textContent = '^';
    if (floorDown) floorDown.textContent = 'v';
    document.getElementById('auto-refresh-toggle').addEventListener('change', setupRefresh);
    document.getElementById('refresh-interval').addEventListener('input', setupRefresh);
    document.getElementById('guild-map-zoom-in').addEventListener('click', () => changeGuildMapZoom(1));
    document.getElementById('guild-map-zoom-out').addEventListener('click', () => changeGuildMapZoom(-1));
    document.getElementById('guild-map-floor-up').addEventListener('click', () => changeGuildMapFloor(-1));
    document.getElementById('guild-map-floor-down').addEventListener('click', () => changeGuildMapFloor(1));
    document.getElementById('guild-map-follow-selected')?.addEventListener('change', event => setGuildMapFollow(event.target.checked));
    document.getElementById('guild-map-pan-up')?.addEventListener('click', () => panGuildMap(0, -64));
    document.getElementById('guild-map-pan-left')?.addEventListener('click', () => panGuildMap(-64, 0));
    document.getElementById('guild-map-pan-center')?.addEventListener('click', () => setGuildMapFollow(true));
    document.getElementById('guild-map-pan-right')?.addEventListener('click', () => panGuildMap(64, 0));
    document.getElementById('guild-map-pan-down')?.addEventListener('click', () => panGuildMap(0, 64));
    const guildMap = document.getElementById('guild-map');
    guildMap?.addEventListener('pointerdown', beginGuildMapDrag);
    guildMap?.addEventListener('pointermove', moveGuildMapDrag);
    guildMap?.addEventListener('pointerup', endGuildMapDrag);
    guildMap?.addEventListener('pointercancel', endGuildMapDrag);
    document.getElementById('guild-map-show-deaths').addEventListener('change', event => {
        showWolfDeaths = event.target.checked;
        renderGuildMinimap();
    });
    document.getElementById('guild-map-show-heatmap').addEventListener('change', event => {
        showWolfHeatmap = event.target.checked;
        renderGuildMinimap();
    });
    document.getElementById('guild-map-heatmap-regional')?.addEventListener('change', event => {
        wolfHeatmapRegional = event.target.checked;
        const byFloor = document.getElementById('guild-map-heatmap-by-floor');
        if (wolfHeatmapRegional) {
            wolfHeatmapByFloor = false;
            if (byFloor) byFloor.checked = false;
        } else {
            wolfHeatmapByFloor = true;
            if (byFloor) byFloor.checked = true;
        }
        renderGuildMinimap();
    });
    document.getElementById('guild-map-heatmap-by-floor')?.addEventListener('change', event => {
        wolfHeatmapByFloor = event.target.checked;
        const regional = document.getElementById('guild-map-heatmap-regional');
        if (wolfHeatmapByFloor) {
            wolfHeatmapRegional = false;
            if (regional) regional.checked = false;
        } else {
            wolfHeatmapRegional = true;
            if (regional) regional.checked = true;
        }
        renderGuildMinimap();
    });
    document.getElementById('guild-map-heatmap-project-z7')?.addEventListener('change', event => {
        wolfHeatmapProjectZ7 = event.target.checked;
        renderGuildMinimap();
    });
    document.getElementById('guild-map-go-heatmap')?.addEventListener('click', goToHeatmapFloor);
    document.getElementById('guild-map-heatmap-range').addEventListener('change', event => {
        wolfHeatmapRange = event.target.value;
        renderGuildMinimap();
    });
    document.getElementById('nav-debug-refresh')?.addEventListener('click', fetchNavDebug);
    document.getElementById('nav-debug-simulate')?.addEventListener('click', simulateNavCoordinate);
    document.getElementById('tier-create-group')?.addEventListener('click', createTierGroup);
    document.getElementById('tier-start-collection')?.addEventListener('click', startTierCollection);
    document.getElementById('tier-character-search')?.addEventListener('input', () => renderTierCharacters(tierOrbs?.participants || []));
    document.getElementById('tier-receiver-search')?.addEventListener('input', () => renderTierReceivers(tierOrbs?.receivers || []));
    document.getElementById('tier-save-settings').addEventListener('click', saveTierSettings);
    document.getElementById('access-create')?.addEventListener('click', createDashboardUser);
    window.addEventListener('resize', () => {
        if (document.getElementById('locations-tab')?.classList.contains('active')) {
            renderGuildMinimap();
        }
    });

    fetchStats();
    setupRefresh();
});
