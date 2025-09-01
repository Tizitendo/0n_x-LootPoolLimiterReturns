log.info("Successfully loaded " .. _ENV["!guid"] .. ".")
mods["RoRRModdingToolkit-RoRR_Modding_Toolkit"].auto(true)
mods.on_all_mods_loaded(function()
    for k, v in pairs(mods) do
        if type(v) == "table" and v.tomlfuncs then
            Toml = v
        end
    end
    params = {
        numWhites = 20,
        numGreens = 15,
        numReds = -1,
        PoolSizeVariance = 5,
        forceCategories = true
    }
    params = Toml.config_update(_ENV["!guid"], params) -- Load Save
end)
NAMESPACE = _ENV["!guid"]

whiteItems = {}
greenItems = {}
redItems = {}

categoryRatioWhite = {}
categoryRatioGreen = {}
categoryRatioRed = {}
categories = {Item.LOOT_TAG.category_damage, Item.LOOT_TAG.category_healing, Item.LOOT_TAG.category_utility}

Initialize(function()
    local function add_category(item, ratioList)
        local offset = math.random(1, 3)
        for i = offset, offset + 3 do
            local category = i % 3 + 1
            if item.loot_tags & categories[category] ~= 0 then
                ratioList[category] = ratioList[category] + 1
                return
            end
        end
        log.warning("error")
    end

    local function adjust_ratio(ratioList, numItems, maxItems)
        for i = 1, 3 do
            ratioList[i] = ratioList[i] * numItems / maxItems
        end

        local target = numItems / 3
        local biggestdif = 0
        local diffIndex = 1

        for i = 1, 3 do
            if math.abs(ratioList[i] - target) >= biggestdif then
                biggestdif = math.abs(ratioList[i] - target)
                diffIndex = i
            end
            if ratioList[i] >= target then
                ratioList[i] = math.floor(ratioList[i])
            else
                ratioList[i] = math.floor(ratioList[i]) + 1
            end
        end
        
        ratioList[diffIndex] = ratioList[diffIndex] + numItems - ratioList[1] - ratioList[2] - ratioList[3]
    end

    local function shuffle_table(t)
        for i = #t, 2, -1 do
            local j = math.random(i)
            t[i], t[j] = t[j], t[i]
        end
    end

    local function apply_blacklist(itemlist, numItems, ratioList) 
        if numItems < 0 then return end
        numItems = math.min(numItems + math.random(-params.PoolSizeVariance, params.PoolSizeVariance), #itemlist)
        ratioList = {0, 0, 0}
        for _, item in ipairs(itemlist) do
            item:toggle_loot(false)
            add_category(item, ratioList)
        end

        adjust_ratio(ratioList, numItems, #itemlist)
        shuffle_table(itemlist)

        for i = 1, 3 do
            log.info(ratioList[i])
        end

        if not params.forceCategories then
            for i = 1, 3 do
                ratioList[i] = ratioList[i] + 100
            end
        end

        local i = 1
        while i <= numItems do
            local offset = math.random(1, 3)
            for o = offset, offset + 3 do
                local category = o % 3 + 1
                if itemlist[i].loot_tags & categories[category] ~= 0 and ratioList[category] > 0 then
                    itemlist[i]:toggle_loot(true)
                    ratioList[category] = ratioList[category] - 1
                    numItems = numItems - 1
                    break
                end
            end
            numItems = math.min(numItems + 1, #itemlist)
            i = i + 1
        end
    end

    for _, item in ipairs(Item.find_all()) do
        if item:is_loot() then
            if item.tier == Item.TIER.common then
                table.insert(whiteItems, item)
            end
            if item.tier == Item.TIER.uncommon then
                table.insert(greenItems, item)
            end
            if item.tier == Item.TIER.rare then
                table.insert(redItems, item)
            end
        end
    end

    gm.pre_script_hook(gm.constants.run_create, function()
        apply_blacklist(whiteItems, params.numWhites, categoryRatioWhite)
        apply_blacklist(greenItems, params.numGreens, categoryRatioGreen)
        apply_blacklist(redItems, params.numReds, categoryRatioRed)
    end)
end, true)



-- Add ImGui window
gui.add_imgui(function()
    if ImGui.Begin("LootPoolLimiter") then
        params.numWhites = ImGui.InputInt("numWhites", params.numWhites, 1, #whiteItems)
        params.numGreens = ImGui.InputInt("numGreens", params.numGreens, 1, #greenItems)
        params.numReds = ImGui.InputInt("numReds", params.numReds, 1, #redItems)
        params.PoolSizeVariance = ImGui.InputInt("PoolSizeVariance", params.PoolSizeVariance, 1, 30)
        params.forceCategories = ImGui.Checkbox("forceCategories", params.forceCategories)
        Toml.save_cfg(_ENV["!guid"], params)
    end
    ImGui.End()
end)
