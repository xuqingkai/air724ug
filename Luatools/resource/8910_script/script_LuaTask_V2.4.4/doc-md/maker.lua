
function make(lines)

local text = {"","@[TOC]", ""}
local lastLine = 1

local moduleName

--获取本文件的注释
local moduleInfo = {lines[1]:match("%-%-%- *(.+)"),}
for i=2,#lines do
    if lines[i]:find("@module") then
        moduleName = lines[i]:match("%-%- *@module *(.+)")
        table.insert(text, "# "..lines[i]:match("%-%- *@module *(.+)"))
        table.insert(text, "")
        lastLine = i
        break
    else
        table.insert(moduleInfo, lines[i]:match("%-%- *(.+)"))
    end
end
moduleInfo = table.concat( moduleInfo, "\r\n\r\n")
table.insert(text, moduleInfo)
table.insert(text, "")

--每个函数循环处理
while lastLine < #lines do
    --匹配注释第一行，开始处理该函数
    if lines[lastLine]:find("%-%-%- *.+") == 1 and not lines[lastLine]:find("%-%-%-%-") and lines[lastLine+1]:find("%-%-.*") == 1 then
        --函数解释
        local functionInfo = lines[lastLine]:match("%-%-%- *(.+)")
        --table.insert(text, functionInfo)
        local functionName--匹配的函数名
        local arg--匹配的变量名
        local all = {}
        for i=lastLine+1,#lines do
            if lines[i]:find("function ") == 1 then
                lastLine = i+2
                functionName = lines[i]:match("function *(.+)")
                if functionName and functionName:find(" return ") then
                    local ret = functionName:find(" return ")
                    functionName = functionName:sub(1,ret-1)
                end
                break
            elseif lines[i]:find("local +function ") == 1 then
                lastLine = i+2
                functionName = lines[i]:match("function *(.+)")
                functionName = functionName.." (local函数 无法被外部调用)"
                if functionName and functionName:find(" return ") then
                    local ret = functionName:find(" return ")
                    functionName = functionName:sub(1,ret-1)
                end
                break
            elseif lines[i]:find(".*%..* *= *function *%(") == 1 then
                lastLine = i+2
                local funcVars = lines[i]:match(".*%..* *= *function *(.*)")
                functionName = lines[i]:match("(.*%..*) *= *function *%(")..funcVars
                break
            elseif lines[i]:find("socket%.isReady") == 1 then--单独处理socket.isReady函数（太特殊了）
                lastLine = i+2
                functionName = "socket.isReady()"
                break
            elseif lines[i]:find("%w+ *=") == 1 then--匹配常量声明
                lastLine = i+1
                arg = lines[i]:match("(%w+) *=")
                --print(arg)
                break
            elseif lines[i]:find("%-%-%- *.+") == 1 then
                break
            else
                table.insert(all,lines[i])
            end
        end
        if functionName then--匹配成功
            functionName = functionName:gsub(" *, *",", ")
            --加上函数开头
            local functionHead = functionName:match("(.+)%(")
            if functionHead:find("%.") or functionHead:find(":") then
                table.insert(text, "## "..functionName)
            else
                table.insert(text, "## "..moduleName.."."..functionName)
            end
            table.insert(text, "")
            table.insert(text, functionInfo)

            --处理多行注释解释的情况
            local infotemp = {}
            for i=1,#all do
                if all[i]:find("%-%- *[^-](.+)") == 1 and all[i]:find("%-%- *@") ~= 1 then
                    table.insert(infotemp, all[i]:match("%-%- *(.+)"))
                else
                    break
                end
            end
            if #infotemp > 0 then
                table.insert(text, "")
                table.insert(text, table.concat(infotemp,"<br>"))
            end
            table.insert(text, "")

            --防止参数信息不在最开头
            local ptemp,rtemp,utemp = 0,0,0
            for i=1,#all do
                if all[i]:find("%-%- *@") == 1 then
                    if all[i]:find("%-%- *@return") == 1 then
                        rtemp = rtemp == 0 and i or rtemp
                    elseif all[i]:find("%-%- *@usage") == 1 then
                        utemp = utemp == 0 and i or utemp
                    elseif ptemp == 0 and all[i]:find("%-%- *@see") ~= 1 then
                        ptemp = i
                    end
                end
            end
            if ptemp > rtemp and rtemp ~= 0 and utemp ~= 0 then
                print("wrong param "..tostring(ptemp)..","..tostring(rtemp)..","..tostring(utemp)..","..functionName)
                --重新整理顺序，使之正确
                for i=0,utemp - ptemp - 1 do
                    table.insert(all,rtemp+i,table.remove(all,ptemp+i))
                end
            end


            --上次处理的函数信息行数
            local last = 1

            --筛选出传入参数值
            local para = {}
            for i=last,#all do
                if all[i]:find("%-%- *@return") == 1 or all[i]:find("%-%- *@usage") == 1 then
                    last = i
                    break
                else
                    if all[i]:find("%-%- *@") == 1 then
                        --获取参数信息与解释
                        local choseType = nil
                        local ft,fi = all[i]:match("%-%- *@(%w+) (.+)")
                        if not ft then
                            ft,fi = all[i]:match("%-%- *@(%w+)%[opt=.+%] (.+)")
                            choseType = all[i]:match("%-%- *@%w+%[opt=(.+)%] .+")
                        end
                        if ft then
                            local ppp = {type=ft}
                            if fi then
                                local fn, fe = fi:match("(.+) (.+)")
                                if moduleName == "log" then
                                    --print("fn" , fn, "fe", fe)
                                end
                                if fn and fe and #fn < 32 then
                                    ppp["name"] = fn:trim()
                                    ppp["info"] = fe:trim()
                                else
                                    ppp["name"] = "-"
                                    ppp["info"] = fi
                                end
                            else
                                ppp["info"] = ""
                                ppp["name"] = ""
                            end
                            if choseType then
                                ppp["info"] = "**可选参数，默认为`" .. choseType .. "`** " .. ppp["info"]
                            end
                            table.insert(para, ppp)
                        end
                    else
                        if para[#para] then
                            para[#para].info = para[#para].info.."<br>"..(all[i]:match("%-%- *(.+)") or "")
                        end
                    end
                end
                if i == #all then last = i end--没匹配到下一个，避免出错，直接结束本区块
            end
            local paraText = {"|名称|传入值类型|释义|","|-|-|-|"}
            for i=1,#para do
                table.insert(paraText, "|" .. para[i].name .. "|"..para[i].type.."|"..para[i].info.."|")
            end
            table.insert(text, "* 参数")
            table.insert(text, "")
            if #para ~= 0 then
                table.insert(text, table.concat(paraText,"\r\n"))
            else
                table.insert(text, "无")
            end
            table.insert(text, "")

            --筛选出返回值参数
            local returnInfo = {}
            for i=last,#all do
                -- if functionName == "getState()" then
                --     print(all[i])
                -- end
                if all[i]:find("%-%- *@return") == 1 then
                    table.insert(returnInfo, all[i]:match("%-%- *@return *(.+)") or "")
                elseif all[i]:find("%-%- *@usage") == 1 then
                    last = i
                    break
                else
                    if returnInfo[#returnInfo] then
                        returnInfo[#returnInfo] = returnInfo[#returnInfo].."<br>"..(all[i]:match("%-%- *@return *(.+)") or all[i]:match("%-%- *(.+)") or "")
                    end
                end
                if i == #all then last = i end--没匹配到下一个，避免出错，直接结束本区块
            end
            table.insert(text, "* 返回值")
            table.insert(text, "")
            if #returnInfo ~= 0 then
                table.insert(text, table.concat(returnInfo,"\r\n"))
            else
                table.insert(text, "无")
            end
            table.insert(text, "")

            if last ~= #all+1 then
                --筛选出示例参数
                local example = {}
                for i=last,#all do
                    local usage
                    if all[i]:find("%-%- *@usage.+") == 1 then
                        usage = all[i]:match("%-%- *@usage *(.+)") or ""
                    elseif all[i]:find("%-%- *@see") == 1 then
                        usage = "--另见："..(all[i]:match("%-%- *@see *(.+)") or "")
                    elseif all[i]:find("%-%- *.+") == 1 and all[i]:find("%-%- *@usage") ~= 1 and all[i]:find("%-%- *@return") ~= 1 then
                        usage = all[i]:match("%-%- *(.+)") or ""
                    end
                    if usage and usage:gsub(" *","") ~= "" then--过滤掉空行
                        table.insert(example, usage)
                    end
                    if i == #all then last = i end--没匹配到下一个，避免出错，直接结束本区块
                end

                --第一个字符为中文的，该行直接注释掉
                for i=1,#example do
                    local first = example[i]:byte()
                    if not (first>0 and first<=127) then
                        example[i] = "-- "..example[i]
                    end
                end

                table.insert(text, "* 例子")
                table.insert(text, "")
                if #example ~= 0 then
                    table.insert(text, "```lua")
                    table.insert(text, table.concat(example,"\r\n"))
                    table.insert(text, "```")
                else
                    table.insert(text, "无")
                end
                table.insert(text, "")
            end



            table.insert(text, "---")
            table.insert(text, "")
        elseif arg then
            table.insert(text, "### "..moduleName.."."..arg)
            table.insert(text, "")
            table.insert(text, "常量值，"..functionInfo)
            table.insert(text, "")
            local argInfo = table.concat(all, "\r\n\r\n"):gsub("%-%- *","")
            table.insert(text, argInfo)
            table.insert(text, "")
            table.insert(text, "---")
            table.insert(text, "")
        else
            lastLine = lastLine + 1
        end
    else
        lastLine = lastLine + 1
    end
end

return table.concat(text, "\r\n")
end

return make