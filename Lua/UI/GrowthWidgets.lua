-- 仅缓存显示 Widget；不拥有角色或事件状态。
local M={}
function M.Rows(panel,key,name,rows,action)
    panel.pools=panel.pools or {};local pool=panel.pools[key] or {};panel.pools[key]=pool
    for i,row in ipairs(rows) do
        if not pool[i] then pool[i]=panel:CreateWidget(name,panel.view[key]) end
        pool[i]:SetData(row,panel.view.Style,action and function() action(row) end or nil)
    end
    for i=#rows+1,#pool do pool[i]:SetData(nil) end
end
return M
