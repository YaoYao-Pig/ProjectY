-- 兼容现有AdventureValidation.RunFile入口，实际执行三层原生轨迹。
local rows=dofile('Tools/Tests/shipwreck_v2_preview.lua')
return 'PASS Shipwreck V2: real four-member floor transitions, loot, return and re-entry; '..#rows..' native preview states'
