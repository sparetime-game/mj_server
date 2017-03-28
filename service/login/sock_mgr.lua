local skynet = require "skynet"
local socket = require "socket"
local utils = require "utils"
local packer = require "packer"
local account_mgr = require "account_mgr"

local M = {}

function M:start(conf)
    self.gate = skynet.newservice("gate")

    skynet.call(self.gate, "lua", "open", conf)

    skynet.error("login service listen on port "..conf.port)

    self:register_callback()
end

-------------------处理socket消息开始--------------------
function M:open(fd, addr)
    skynet.error("New client from : " .. addr)
    skynet.call(self.gate, "lua", "accept", fd)
end

function M:close(fd)
    skynet.error("socket close "..fd)
end

function M:error(fd, msg)
    skynet.error("socket error "..fd)
end

function M:warning(fd, size)
    -- size K bytes havn't send out in fd
    skynet.error("socket warning "..fd)
end

function M:data(fd, msg)
    skynet.error(string.format("socket data fd = %d, len = %d ", fd, #msg))
    local proto_id, params = string.unpack(">Hs2", msg)

    skynet.error(string.format("msg id:%d content:%s", proto_id, params))
    params = utils.str_2_table(params)

    self:dispatch(fd, proto_id, params)
end
-------------------处理socket消息结束--------------------

-------------------网络消息回调函数开始------------------
function M:register_callback()
    self.dispatch_tbl = {
        [1] = self.login,
        [3] = self.register
    }
end

function M:dispatch(fd, proto_id, params)
    local f = self.dispatch_tbl[proto_id]
    if not f then
        skynet.error("can't find socket callback "..proto_id)
        return
    end

    local ret_msg = f(self, fd, params)
    if ret_msg then
        skynet.error("ret msg:"..utils.table_2_str(ret_msg))
        socket.write(fd, packer.pack(proto_id, ret_msg))
    end
end

function M:login(fd, msg)
    skynet.error(string.format("verfy account:%s passwd:%s ", msg.account, msg.passwd))
    local success, errmsg = account_mgr:verify(msg.account, msg.passwd)
    if not success then
        return {errmsg = errmsg}
    end

    return {token = "token"}
end

function M:register(fd, msg)
    if account_mgr:get_by_account(msg.account) then
        return {errmsg = "account exist"}
    end

    local success = account_mgr:register(msg.account, msg.passwd)

    return {token = "token"}
end
-------------------网络消息回调函数结束------------------

return M
