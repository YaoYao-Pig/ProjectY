local M={}
function M.Escape(value)
    return (assert(value):gsub('<','<noparse><</noparse>'))
end
return M
