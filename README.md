# Fivem Postal Job (Sandbox/Mythic Framework)

A FiveM postal job script for SandboxRP version of Mythic framework.

Note: Requires Sandbox version of Mythic framework


You can rename the files as you wish and place them within their respective directories within sandbox-labor (client/server/config).

You must also add the following to sandbox-labor > server > startup.lua (edit the pay & reputation as you wish).

```lua
Labor.Jobs:Register("Postal", "Postal", 0, 1500, 85, false, {
        { label = "Rank 1", value = 1500 },
        { label = "Rank 2", value = 3000 },
        { label = "Rank 3", value = 7000 },
        { label = "Rank 4", value = 10000 },
        { label = "Rank 5", value = 12000 },
    })
```

Edit job rewards in server.lua

To Do: Integrate reputation progression with job rewards