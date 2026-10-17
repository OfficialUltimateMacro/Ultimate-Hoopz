-- Editable Ultimate preferences layered over the recovered Blessed program.
local UltimatePreferences = {
    AutoGuardKey = "L", HideAimbotKeyPicker = true,
    Aimbot = true, AutoGuard = true, BallCheck = true,
    MatchTargetJump = true, AutoPlay = false,
    BallMagnet = true, MagnetStrength = 50,
    BallReach = true, ReachStrength = 10,
    WalkSpeed = 0.01, AntiDrop = true,
    LogoURL = "https://raw.githubusercontent.com/OfficialUltimateMacro/Ultimate-Hoopz/main/assets/ultimate-wordmark.png",
    LogoCache = "Ultimate-wordmark-061784a8.png"
}
local ULTIMATE_LOGO_TOKEN = "ultimate://wordmark"
local logoImage, logoAttempted
local function resolveUltimateLogo(environment)
    if logoAttempted then return logoImage end
    logoAttempted = true
    local customAsset = environment.getcustomasset or environment.getsynasset
    if type(customAsset) ~= "function" or type(environment.writefile) ~= "function" then return nil end
    local ok, value = pcall(function()
        if type(environment.isfile) ~= "function" or not environment.isfile(UltimatePreferences.LogoCache) then
            local bytes = environment.game:HttpGet(UltimatePreferences.LogoURL)
            assert(type(bytes) == "string" and bytes:sub(1, 8) == "\137PNG\r\n\26\n", "Logo download was not a PNG")
            environment.writefile(UltimatePreferences.LogoCache, bytes)
        end
        return customAsset(UltimatePreferences.LogoCache)
    end)
    if ok and type(value) == "string" and value ~= "" then logoImage = value end
    return logoImage
end
local function applyUltimateProperty(target, key, value, environment)
    if UltimateExtensions then UltimateExtensions:ObserveInstance(target, key, value, environment) end
    if key == "Image" and value == ULTIMATE_LOGO_TOKEN
        and environment.typeof(target) == "Instance" then
        local resolved = resolveUltimateLogo(environment)
        target.Image = resolved or ""
        target.ScaleType = environment.Enum.ScaleType.Fit
        if not resolved and not target:FindFirstChild("UltimateWordmark") then
            local wordmark = environment.Instance.new("TextLabel")
            wordmark.Name = "UltimateWordmark"
            wordmark.BackgroundTransparency = 1
            wordmark.Size = environment.UDim2.fromScale(1, 1)
            wordmark.Text = BRAND
            wordmark.Font = environment.Enum.Font.Fantasy
            wordmark.TextColor3 = environment.Color3.fromRGB(255, 113, 175)
            wordmark.TextStrokeColor3 = environment.Color3.fromRGB(54, 10, 36)
            wordmark.TextStrokeTransparency = 0
            wordmark.TextScaled = true
            wordmark.ZIndex = target.ZIndex + 1
            wordmark.Parent = target
        end
    else target[key] = value end
end
local function applyUltimateDefaults(root)
    -- The original decoded data stays untouched on disk. These sites are the
    -- recovered initializer operations, applied before self-modification runs.
    assert(root[6][1972] == "X", "Unexpected aimbot initializer")
    root[6][1969] = UltimatePreferences.Aimbot
    root[6][1972] = "Unknown" -- The initializer assignment itself is skipped.
    root[6][1978] = UltimatePreferences.AutoGuard
    root[6][1979] = UltimatePreferences.BallCheck
    root[6][2038] = UltimatePreferences.AutoGuardKey
    root[6][1399] = "Auto Guard key"
    root[6][1977] = UltimatePreferences.WalkSpeed
    root[6][2009] = UltimatePreferences.BallReach
    root[6][2010] = UltimatePreferences.ReachStrength
    root[6][2011] = UltimatePreferences.AntiDrop
    root[6][2040] = UltimatePreferences.BallMagnet
    root[6][2041] = UltimatePreferences.MagnetStrength
end
