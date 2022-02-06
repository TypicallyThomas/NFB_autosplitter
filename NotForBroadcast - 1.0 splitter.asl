state("NotForBroadcast") {}

startup
{
    var SplitScenes = new HashSet<string>
    {
        "02 Level 1",
        "03 Level 2",
        "04 Level 3",
        "05 Level 4",
        "06 Level 0V50",
        "07 Level 14",
        "08 Level 15",
        "09 Level 16",
        "Incident System",
        "10 Level 17",
        "11 Level 18",
        "12 Level 19"
    };

    vars.AdditionalPauses = new HashSet<string> { "00 Splash Screen", "Loading Screen" };

    settings.Add("sceneSplits", true, "Split after finishing a scene:");
    foreach (string scene in SplitScenes)
        settings.Add(scene, true, scene, "sceneSplits");

    vars.TimerStart = (EventHandler) ((s, e) => vars.DoneSplits = new HashSet<string>());
    timer.OnStart += vars.TimerStart;
}

init
{
    vars.DoneSplits = new HashSet<string>();
    var UnityPlayer = modules.FirstOrDefault(m => m.ModuleName == "UnityPlayer.dll");
    var UnityPlayerScanner = new SignatureScanner(game, UnityPlayer.BaseAddress, UnityPlayer.ModuleMemorySize);

    var SceneManager = IntPtr.Zero;
    var SceneManagerSig = new SigScanTarget(3, "48 8B 0D ???????? 48 8D 55 ?? 89 45 ?? 0F B6 85");
    SceneManagerSig.OnFound = (p, s, ptr) => IntPtr.Add(ptr + 4, p.ReadValue<int>(ptr));

    int iteration = 0;
    while (iteration++ < 50)
        if ((SceneManager = UnityPlayerScanner.Scan(SceneManagerSig)) != IntPtr.Zero) break;

    if (!(vars.SigFound = SceneManager != IntPtr.Zero)) return;

    Func<string, string> PathToName = (path) =>
    {
        if (String.IsNullOrEmpty(path) || !path.StartsWith("Assets/")) return null;
        else return System.Text.RegularExpressions.Regex.Matches(path, @".+/(.+).unity")[0].Groups[1].Value;
    };

    vars.UpdateScenes = (Action) (() =>
    {
        current.ThisScene = PathToName(new DeepPointer(SceneManager, 0x48, 0x10, 0x0).DerefString(game, 112)) ?? old.ThisScene;
        current.NextScene = PathToName(new DeepPointer(SceneManager, 0x28, 0x0, 0x10, 0x0).DerefString(game, 112)) ?? old.NextScene;
    });
}

update
{
    if (!vars.SigFound) return false;
    vars.UpdateScenes();
}

start
{
    return old.ThisScene != current.ThisScene &&
           old.ThisScene == "01 Main Menu";
}

split
{
    if (old.NextScene != current.NextScene &&
        !vars.DoneSplits.Contains(old.NextScene))
    {
        vars.DoneSplits.Add(old.NextScene);
        return settings[old.NextScene];
    }
}

reset
{
    return old.ThisScene != current.ThisScene &&
           current.ThisScene == "01 Main Menu";
}

isLoading
{
    if (current.NextScene == "Incident System" && (current.ThisScene.StartsWith("0") || current.ThisScene.StartsWith("1"))) return false;
    return current.ThisScene != current.NextScene ||
           vars.AdditionalPauses.Contains(current.ThisScene);
}

shutdown
{
    timer.OnStart -= vars.TimerStart;
}
