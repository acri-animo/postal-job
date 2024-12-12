local _joiner = nil
local _working = false
local _blip = nil
local eventHandlers = {}
local _entities = {}
local _state

-- Players can collect mail from any of these props anywhere in the city
local postalBoxes = {
    `prop_postbox_01a`,
    `prop_postbox_02a`,
    `prop_postbox_01b`,
    `prop_postbox_01c`,
    `prop_postbox_02b`
}

-- Startup event
AddEventHandler("Labor:Client:Setup", function()
    -- Ped to start job
    PedInteraction:Add("PostalJob", GetHashKey("s_m_m_postal_01"), vector3(78.886, 112.563, 80.168), 164.319, 25.0, {
        {
            icon = "handshake-angle",
            text = "Start Work",
            event = "Postal:Client:StartJob",
            tempjob = "Postal",
            isEnabled = function()
                return not _working
            end,
        },
        {
            icon = "truck-fast",
            text = "Borrow Postal Van",
            event = "Postal:Client:PostalSpawn",
            tempjob = "Postal",
            isEnabled = function()
                return _working and _state == 1
            end,
        },
        {
            icon = "reply-all",
            text = "Return Postal Van",
            event = "Postal:Client:PostalSpawnRemove",
            tempjob = "Postal",
            isEnabled = function()
                return _working and _state == 3
            end,
        },
        {
            icon = "money-check-dollar",
            text = "Complete Job",
            event = "Postal:Client:TurnIn",
            tempjob = "Postal",
            isEnabled = function()
                return _working and _state == 4
            end,
        },
    }, "envelopes-bulk")
end)

------------------
-- Events/Handlers
------------------

RegisterNetEvent("Postal:Client:OnDuty", function(joiner, time)
    _joiner = joiner
    DeleteWaypoint()
    SetNewWaypoint(78.886, 112.563)

    _blip = Blips:Add("PostalStart", "Postal Manager", { x = 78.886, y = 112.563, z = 0 }, 480, 2, 1.4)

    eventHandlers["startup"] = RegisterNetEvent(string.format("Postal:Client:%s:Startup", joiner), function()
        _working = true
        for k, v in ipairs(postalBoxes) do
            Targeting:AddObject(v, "envelope", {
                {
                    icon = "hand",
                    text = "Collect Mail",
                    event = "Postal:Client:MailDeposit",
                    data = "Postal",
                    isEnabled = function(data, entity)
                        -- Prevents player from targeting a mailbox they have already collected from
                        return not _entities[entity.entity]
                            and MailObject == nil
                    end,                    
                },
            }, 3.0)
        end
    end)

    eventHandlers["mail-deposit"] = AddEventHandler("Postal:Client:MailDeposit", function(entity, data)
        if MailObject ~= nil then
            DetachEntity(MailObject, 1, false)
            DeleteObject(MailObject)
            MailObject = nil
        end

        -- Progress bar when collecting mail
        Progress:Progress({
            name = "mail_deposit",
            duration = math.random(20, 25) * 1000,
            label = "Collecting Mail",
            useWhileDead = false,
            canCancel = true,
            vehicle = false,
            animation = {
                anim = "search",
            },
            controlDisables = {
                disableMovement = true,
                disableCarMovement = true,
                disableCombat = true,
            },
        }, function(cancelled)
            if not cancelled then
                -- Sends the entity ID to server to track each mailbox a player collects (preventing someone from collecting from the same mailbox over and over)
                local mailboxEntityId = entity.entity
                Callbacks:ServerCallback("Postal:MailDeposit", { mailboxEntity = mailboxEntityId }, function(s)
                    if s then
                        LocalPlayer.state.carryingMail = true
                        -- This tracks the mailboxes player collects on client side to prevent targeting of a mailbox they already collected
                        _entities[mailboxEntityId] = true

                        if next(_entities) ~= nil then
                            _state = 3
                        end
                    end
                end)
            end
        end)
    end)

    eventHandlers["toss-mail"] = AddEventHandler("Postal:Client:TossMail", function()
        Callbacks:ServerCallback("Postal:MailPutIn", {}, function(s)
            if s then
                LocalPlayer.state.carryingMail = false
            end
        end)
    end)

    eventHandlers["spawn-van"] = AddEventHandler("Postal:Client:PostalSpawn", function()
        Callbacks:ServerCallback("Postal:PostalSpawn", {}, function(animo)
            if not animo then
                Notification:Error("Attempting to spawn postal van you pepega.")
                return
            end
            SetEntityAsMissionEntity(entity)
        end)
        _state = 2
    end)    

    eventHandlers["despawn-van"] = AddEventHandler("Postal:Client:PostalSpawnRemove", function()
        Callbacks:ServerCallback("Postal:PostalSpawnRemove", {})
    end)

    eventHandlers["return-van"] = RegisterNetEvent(string.format("Postal:Client:%s:ReturnVan", joiner), function()
        _state = 4
    end)

    eventHandlers["turn-in"] = AddEventHandler("Postal:Client:TurnIn", function()
        Callbacks:ServerCallback("Postal:TurnIn", _joiner)
    end)
end)

AddEventHandler("Postal:Client:StartJob", function()
    Callbacks:ServerCallback("Postal:StartJob", _joiner, function(animo)
        if not animo then
            Notification:Error("Unable To Start Job")
        end
    end)
    _state = 1
end)

RegisterNetEvent("Postal:Client:OffDuty", function(time)
    for k, v in pairs(eventHandlers) do
        RemoveEventHandler(v)
    end

    for k, v in ipairs(postalBoxes) do
        Targeting:RemoveObject(v)
    end

    if _blip ~= nil then
        Blips:Remove("PostalStart")
        RemoveBlip(_blip)
        _blip = nil
    end

    if LocalPlayer.state.carryingMail or MailObject ~= nil then
        DetachEntity(MailObject, 1, false)
        DeleteObject(MailObject)
        LocalPlayer.state.carryingMail = false
    end

    eventHandlers = {}
    _joiner = nil
    _working = false
    MailObject = nil
    _state = 0
end)