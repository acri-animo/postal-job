local _JOB = "Postal"

local _joiners = {}
local _Postal = {}
local _usedMailboxes = {}

local _lootTable = {
    "plastic",
    "iron_bar",
}

AddEventHandler("Labor:Server:Startup", function()
    Callbacks:RegisterServerCallback("Postal:StartJob", function(source, data, cb)
        if _Postal[data] == nil then
            _Postal[data] = { state = 0 }
        end
        if _Postal[data].state == 0 then
            _Postal[data].state = 1
            Labor.Offers:Task(_joiners[source], _JOB, "Grab a postal van")
            Labor.Workgroups:SendEvent(data, string.format("Postal:Client:%s:Startup", data))
            cb(true)
        else
            cb(false)
        end
    end)

    local _isSpawningVan = false
    Callbacks:RegisterServerCallback("Postal:PostalSpawn", function(source, data, cb)
        if _isSpawningVan then
            cb(false)
            return
        end
        if _joiners[source] ~= nil and _Postal[_joiners[source]].van == nil and _Postal[_joiners[source]].state == 1 then
            _isSpawningVan = true
            Vehicles:SpawnTemp(source, `boxville2`, 'automobile', vector3(64.487, 122.632, 79.148), 157.757, function(veh, VIN)
                Vehicles.Keys:Add(source, VIN)
                _Postal[_joiners[source]].van = veh
                _Postal[_joiners[source]].state = 2
                Labor.Offers:Start(_joiners[source], _JOB, "Collect Mail", 15)
                _isSpawningVan = false
            
                cb(veh)
            end, false) -- false here to spawn it non-networked            
        end
    end)

    Callbacks:RegisterServerCallback("Postal:PostalSpawnRemove", function(source, data, cb)
        if _joiners[source] ~= nil and _Postal[_joiners[source]].van ~= nil then
            if _Postal[_joiners[source]].state == 3 then
                local vanCoords = GetEntityCoords(_Postal[_joiners[source]].van)
                local pedCoords = GetEntityCoords(GetPlayerPed(source))
                local distance = #(pedCoords - vanCoords)
                if distance <= 25 then
                    Vehicles:Delete(_Postal[_joiners[source]].van, function()
                        _Postal[_joiners[source]].van = nil
                        _Postal[_joiners[source]].state = 4
                        Labor.Workgroups:SendEvent(_joiners[source], string.format("Postal:Client:%s:ReturnVan", _joiners[source]))
                        Labor.Offers:Task(_joiners[source], _JOB, "Speak with the Postal Manager")
                    end)
                else
                    Execute:Client(source, "Notification", "Error", "Van Needs To Be With You")
                end
            end
        end
    end)

    Callbacks:RegisterServerCallback("Postal:MailDeposit", function(source, data, cb)
        if _joiners[source] ~= nil and _Postal[_joiners[source]].state == 2 then
            -- Ensure mailboxes table is initialized
            if _usedMailboxes[source] == nil then
                _usedMailboxes[source] = {}
            end
    
            -- Use the entity ID directly instead of the network ID
            local mailboxEntityId = data.mailboxEntity
            if _usedMailboxes[source][mailboxEntityId] then
                Execute:Client(source, "Notification", "Error", "You've already used this mailbox")
                cb(false)
                return
            end
    
            Labor.Workgroups:SendEvent(_joiners[source], string.format("Postal:Client:%s:Action", _joiners[source]), data)
    
            local char = Fetch:CharacterSource(source)
            if char:GetData("TempJob") == _JOB then
                local luck = math.random(100)
                if luck >= 50 then
                    Inventory:AddItem(char:GetData("SID"), _lootTable[math.random(#_lootTable)], 1, {}, 1)
                end
    
                if Labor.Offers:Update(_joiners[source], _JOB, 1, true) then
                    _Postal[_joiners[source]].tasks = (_Postal[_joiners[source]].tasks or 0) + 1
    
                    -- Mark the mailbox as used using the entity ID
                    _usedMailboxes[source][mailboxEntityId] = true
    
                    if _Postal[_joiners[source]].tasks >= 1 then
                        _Postal[_joiners[source]].state = 3
                        Labor.Workgroups:SendEvent(_joiners[source], string.format("Postal:Client:%s:EndRoutes", _joiners[source]))
                        Labor.Offers:Task(_joiners[source], _JOB, "Return your van")
                    end
                end
                cb(true)
            else
                cb(false)
            end
        else
            cb(false)
        end
    end)    

    Callbacks:RegisterServerCallback("Postal:TurnIn", function(source, data, cb)
        if _joiners[source] ~= nil and (_Postal[_joiners[source]].tasks or 0) >= 1 then
            local char = Fetch:CharacterSource(source)
            if char:GetData("TempJob") == _JOB and _Postal[_joiners[source]].state == 4 then
                _Postal[_joiners[source]].state = 5
                Labor.Offers:ManualFinish(_joiners[source], _JOB)
                cb(true)
            else
                Execute:Client(source, "Notification", "Error", "Unable To Finish Job")
                cb(false)
            end
        else
            Execute:Client(source, "Notification", "Error", "You've Not Completed All Deliveries")
            cb(false)
        end
    end)
end)

AddEventHandler("Postal:Server:OnDuty", function(joiner, members, isWorkgroup)
    _joiners[joiner] = joiner
    _Postal[joiner] = {
        joiner = joiner,
        isWorkgroup = isWorkgroup,
        started = os.time(),
        state = 0,
        tasks = 0,
    }

    local char = Fetch:CharacterSource(joiner)
    char:SetData("TempJob", _JOB)
    Phone.Notification:Add(joiner, "Job Activity", "You started a job", os.time(), 6000, "labor", {})
    TriggerClientEvent("Postal:Client:OnDuty", joiner, joiner, os.time())

    Labor.Offers:Task(joiner, _JOB, "Speak with the Postal Manager")
    if #members > 0 then
        for k, v in ipairs(members) do
            _joiners[v.ID] = joiner
            local member = Fetch:CharacterSource(v.ID)
            member:SetData("TempJob", _JOB)
            Phone.Notification:Add(v.ID, "Job Activity", "You started a job", os.time(), 6000, "labor", {})
            TriggerClientEvent("Postal:Client:OnDuty", v.ID, joiner, os.time())
        end
    end
end)

AddEventHandler("Postal:Server:OffDuty", function(source, joiner)
    _joiners[source] = nil
    TriggerClientEvent("Postal:Client:OffDuty", source)
end)

AddEventHandler("Postal:Server:FinishJob", function(joiner)
    _Postal[joiner] = nil
    _usedMailboxes[joiner] = nil
end)