
merge = Array.prototype.concat

$(document).on 'templateinit', (event) ->

  class BluelinkItem extends pimatic.DeviceItem # extends pimatic.SwitchItem

    constructor: (templData, @device) ->
      super(templData, @device)

    getItemTemplate: => 'bluelink'

    afterRender: (elements) ->
      super(elements)
      
      @startAircoButton = $(elements).find('[name=startAircoButton]')
      @offAircoButton = $(elements).find('[name=offAircoButton]')
      @lockButton = $(elements).find('[name=lockButton]')
      @unlockButton = $(elements).find('[name=unlockButton]')
      @startChargeButton = $(elements).find('[name=startChargeButton]')
      @stopChargeButton = $(elements).find('[name=stopChargeButton]')
      @refreshButton = $(elements).find('[name=refreshButton]')
      @updateAircoButtons()
      @updateDoorButtons()
      @updateChargingButtons()

      @getAttribute('airco')?.value.subscribe( => @updateAircoButtons() )
      @getAttribute('door')?.value.subscribe( => @updateDoorButtons() )
      @getAttribute('charging')?.value.subscribe( => @updateChargingButtons() )

    modeStartAirco: -> @changeActionTo "start"
    modeOffAirco: -> @changeActionTo "stop"
    modeLock: -> @changeActionTo "lock"
    modeUnlock: -> @changeActionTo "unlock"
    modeStartCharge: -> @changeActionTo "startCharge"
    modeStopCharge: -> @changeActionTo "stopCharge"
    modeRefresh: -> 
      @changeActionTo "stopCharge"
      .then -> @updateRefreshButton()

    updateAircoButtons: =>
      aircoAttr = @getAttribute('airco')?.value()
      switch aircoAttr
        when true
          @startAircoButton.addClass('ui-btn-active')
          @offAircoButton.removeClass('ui-btn-active')
        when false
          @startAircoButton.removeClass('ui-btn-active')
          @offAircoButton.addClass('ui-btn-active')
        else
          @startAircoButton.removeClass('ui-btn-active')
          @offAircoButton.removeClass('ui-btn-active')
      return

    updateDoorButtons: =>
      doorAttr = @getAttribute('door')?.value()
      switch doorAttr
        when true
          @lockButton.addClass('ui-btn-active')
          @unlockButton.removeClass('ui-btn-active')
        when false
          @lockButton.removeClass('ui-btn-active')
          @unlockButton.addClass('ui-btn-active')
        else
          @lockButton.removeClass('ui-btn-active')
          @unlockButton.removeClass('ui-btn-active')
      return

    updateChargingButtons: =>
      chargingAttr = @getAttribute('charging')?.value()
      switch chargingAttr
        when true
          @startChargeButton.addClass('ui-btn-active')
          @stopChargeButton.removeClass('ui-btn-active')
        when false
          @startChargeButton.removeClass('ui-btn-active')
          @stopChargeButton.addClass('ui-btn-active')
        else
          @startChargeButton.removeClass('ui-btn-active')
          @stopChargeButton.removeClass('ui-btn-active')
      return

    updateRefreshButton: =>
      @refreshButton.addClass('ui-btn-active')
      setTimeout(=>
        @refreshButton.removeClass('ui-btn-active')
        return
      , 3000)

    changeActionTo: (_action) ->
      @device.rest.changeActionTo({action: _action}, global: no)
        .done(ajaxShowToast)
        .fail(ajaxAlertFail)

  pimatic.templateClasses['bluelink'] = BluelinkItem
