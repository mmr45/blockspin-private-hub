BlockSpin Auto Fish v0.6.8 - Route persistence patch (untested in game)

This is the user's v0.6.7 Lua with persistent waypoint storage added; not a new auto-seating system.
F4: save fishing position; F5: vendor; F9: ATM; F8: start/stop vehicle route recording; F10: export/save now.
If executor supports writefile/readfile, points and markers are stored in blockspin_route_v068.json and loaded on next run.
If these functions are absent, points are in memory only.
Do not restart Roblox until you see confirmation that saving worked.
Stop: getgenv().BlockSpinV068.stop()
Inspect the JSON file and share it for waypoint analysis.
CAUTION: automatic driving, banking and seat entry are NOT validated.
No third-party closed-source loaders are included.
