$(window).ready(function () {
  const state = {
    locales: {},
    garage: [],
    impounded: [],
    poundCost: null,
    filterGarage: '',
    filterImpound: ''
  };

  const $container = $('#container');
  const $garageList = $('.content .vehicle-list');
  const $impoundList = $('.impounded_content .vehicle-list');
  const $garageEmpty = $('.content h2.empty-state');
  const $impoundEmpty = $('.impounded_content h2.empty-state');

  function calcCondition(props) {
    const bodyHealth = (props.bodyHealth / 1000) * 100;
    const engineHealth = (props.engineHealth / 1000) * 100;
    const tankHealth = (props.tankHealth / 1000) * 100;
    const val = Math.round(((bodyHealth + engineHealth + tankHealth) / 300) * 100);
    return isNaN(val) ? 0 : val;
  }

  function cardTemplate(vehicle, type, amount, locales) {
    const pct = calcCondition(vehicle.props);
    const conditionColor = pct > 70 ? 'good' : pct > 40 ? 'warn' : 'bad';
    let actionLabel = '';
    if (type === 'garage') {
      actionLabel = locales.action + (amount ? ` ($${amount})` : '');
    } else {
      actionLabel = locales.impound_action || locales.action || 'Retrieve';
    }
    return `
      <div class="vehicle-listing" data-model="${vehicle.model}" data-plate="${vehicle.plate}">
        <div><span>${locales.veh_model || 'Model'}:</span> <strong>${vehicle.model}</strong></div>
        <div><span>${locales.veh_plate || 'Plate'}:</span> <strong>${vehicle.plate}</strong></div>
        <div class="condition-wrapper"><span>${locales.veh_condition || 'Condition'}:</span> <span class="condition-percent"><strong>${pct}%</strong></span>
          <div class="condition-bar"><span style="width:${pct}%;${pct<40?'background:linear-gradient(90deg,#ff5d5d,#ff2f4d);':pct<70?'background:linear-gradient(90deg,#ffb347,#ff9500);':''}"></span></div>
        </div>
        <button data-button='${type==='garage'?'spawn':'impounded'}' class='vehicle-action ${type==='impounded'?'red ':''}unstyled-button' data-vehprops='${JSON.stringify(vehicle.props)}'>${actionLabel}</button>
      </div>`;
  }

  function renderLists() {
    // Garage
    const garageFiltered = state.garage.filter(v =>
      v.model.toLowerCase().includes(state.filterGarage) || v.plate.toLowerCase().includes(state.filterGarage)
    );
    if (garageFiltered.length) {
      $garageEmpty.hide();
      $garageList.html(garageFiltered.map(v => cardTemplate(v, 'garage', state.poundCost, state.locales)).join(''));
    } else {
      $garageList.empty();
      $garageEmpty.show();
    }

    // Impounded
    const impoundFiltered = state.impounded.filter(v =>
      v.model.toLowerCase().includes(state.filterImpound) || v.plate.toLowerCase().includes(state.filterImpound)
    );
    if (impoundFiltered.length) {
      $impoundEmpty.hide();
      $impoundList.html(impoundFiltered.map(v => cardTemplate(v, 'impounded', null, state.locales)).join(''));
    } else {
      $impoundList.empty();
      $impoundEmpty.show();
    }
  }

  window.addEventListener('message', function (event) {
    const data = event.data;
    if (data.showMenu) {
      $('#container').fadeIn();
      $('#menu').fadeIn();

      if (data.type === 'impound') {
        $('#header ul').hide();
      } else {
        $('#header ul').show();
      }

      if (data.locales) {
        state.locales = data.locales;
        if (state.locales.no_veh_parking) {
          $garageEmpty.text(state.locales.no_veh_parking);
        }
        if (state.locales.no_veh_impounded) {
          $impoundEmpty.text(state.locales.no_veh_impounded);
        }
      }

      if (data.spawnPoint) { $('#container').data('spawnpoint', data.spawnPoint); }
      if (data.poundCost) { $('#container').data('poundcost', data.poundCost); state.poundCost = data.poundCost; }

      // vehiclesList & vehiclesImpoundedList arrive wrapped in array {json.encode(...)}
      if (data.vehiclesList !== undefined) {
        try {
          const raw = Array.isArray(data.vehiclesList) ? data.vehiclesList[0] : data.vehiclesList;
          state.garage = JSON.parse(raw) || [];
        } catch (e) { state.garage = []; }
      } else { state.garage = []; }

      if (data.vehiclesImpoundedList !== undefined) {
        $('.impounded_content').data('poundName', data.poundName);
        $('.impounded_content').data('poundSpawnPoint', data.poundSpawnPoint);
        try {
          const raw = Array.isArray(data.vehiclesImpoundedList) ? data.vehiclesImpoundedList[0] : data.vehiclesImpoundedList;
          state.impounded = JSON.parse(raw) || [];
        } catch (e) { state.impounded = []; }
      } else { state.impounded = []; }

      renderLists();
    } else if (data.hideAll) {
      $('#container').fadeOut();
    }
  });

  $('#container').hide();

  $('.close').on('click', () => {
    $('#container').hide();
    $.post('https://esx_garage/escape', '{}');
    resetTabs();
  });

  document.onkeyup = function (e) {
    if (e.which === 27) {
      $.post('https://esx_garage/escape', '{}');
      resetTabs();
    }
  };

  function resetTabs() {
    $('.impounded_content').hide();
    $('.content').show();
    $('li[data-page="garage"]').addClass('selected');
    $('li[data-page="impounded"]').removeClass('selected');
  }

  $('li[data-page="garage"]').click(function () {
    $('.impounded_content').hide();
    $('.content').show();
    $('li[data-page="garage"]').addClass('selected');
    $('li[data-page="impounded"]').removeClass('selected');
  });

  $('li[data-page="impounded"]').click(function () {
    $('.content').hide();
    $('.impounded_content').show();
    $('li[data-page="impounded"]').addClass('selected');
    $('li[data-page="garage"]').removeClass('selected');
  });

  // Search filters
  $(document).on('input', '#searchGarage', function () {
    state.filterGarage = $(this).val().trim().toLowerCase();
    renderLists();
  });
  $(document).on('input', '#searchImpounded', function () {
    state.filterImpound = $(this).val().trim().toLowerCase();
    renderLists();
  });

  // Button actions
  $(document).on('click', "button[data-button='spawn'].vehicle-action", function () {
    const spawnPoint = $('#container').data('spawnpoint');
    let poundCost = $('#container').data('poundcost');
    const vehicleProps = $(this).data('vehprops');
    if (poundCost === undefined) poundCost = 0;
    $.post('https://esx_garage/spawnVehicle', JSON.stringify({
      vehicleProps: vehicleProps,
      spawnPoint: spawnPoint,
      exitVehicleCost: poundCost
    }));
    resetTabs();
  });

  $(document).on('click', "button[data-button='impounded'].vehicle-action", function () {
    const vehicleProps = $(this).data('vehprops');
    const poundName = $('.impounded_content').data('poundName');
    const poundSpawnPoint = $('.impounded_content').data('poundSpawnPoint');
    $.post('https://esx_garage/impound', JSON.stringify({
      vehicleProps: vehicleProps,
      poundName: poundName,
      poundSpawnPoint: poundSpawnPoint
    }));
    resetTabs();
  });
});
