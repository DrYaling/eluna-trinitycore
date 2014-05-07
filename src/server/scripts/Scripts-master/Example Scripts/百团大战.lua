
local SMSG_INIT_WORLD_STATES = 0x2C2 --3.3.5
local SMSG_UPDATE_WORLD_STATE = 0x2C3 --3.3.5

-- SMSG_INIT_WORLD_STATES = 0x4C15 --4.3.4
-- SMSG_UPDATE_WORLD_STATE = 0x4816 --4.3.4
 
function Player:InitializeWorldState(Map, Zone, StateID, Value)
        local data = CreatePacket(SMSG_INIT_WORLD_STATES, 18);
        data:WriteULong(Map);
        data:WriteULong(Zone);
        data:WriteULong(0);  
        data:WriteUShort(1);
        data:WriteULong(StateID);
        data:WriteULong(Value);
        self:SendPacket(data)
end
 
function Player:UpdateWorldState(StateID, Value)
        local data = CreatePacket(SMSG_UPDATE_WORLD_STATE, 8);
        data:WriteULong(StateID);
        data:WriteULong(Value);
        self:SendPacket(data)
end
 
--[[ Example:
        player:InitializeWorldState(Map, Zone, StateID, Value)
        player:UpdateWorldState(StateID, Value)
]] 
local ZoneBattles = {
        ["BattleZone"] = {"大竞技场", 0, 5287}, -- 百团大战战场名字, 所在地图ID, 所在 ZoneID
        ["Rewards"] = {0, 0, 20560, 1}, -- 胜利方奖励的金币（铜）, 荣誉值, 道具ID, 道具数量
        ["LostRewards"] = {0, 0, 20560, 1}, -- 失败方奖励的金币（铜）, 荣誉值, 道具ID, 道具数量
        ["MaxScore"] = 1, -- 要杀多少人才赢
        ["Cooldown"] = 3, -- 每多少分钟举行一次百团大战
        ["AlertCooldown"] = 1, -- 每多少分钟给在线全体玩家弹一次框
        [0] = 0, -- 初始给联盟多少分
        [1] = 0, -- 初始给部落多少分
        ["location"] = {
                [0] = {-13195,275,21.856947,1.06}, -- 联盟出生位置 x,y,z,o
                [1] = {-13196.380859,274,21.856947,0.01}; -- 部落出生位置 x,y,z,o
        };
};
 
local function TeamAsString(team)
    if (team == 0) then
        return "联盟"
    else
        return "部落"
    end
end
 
local function HandleReward(player,won)
    local Rewards = "Rewards"
    if(won == 0) then Rewards = "LostRewards" end
    local MoneyReward = ZoneBattles[Rewards][1];
    local HonorReward = ZoneBattles[Rewards][2];
    local ItemReward, ItemRewardCount = ZoneBattles[Rewards][3], ZoneBattles[Rewards][4];

    for k, _ in pairs(ZoneBattles["BattleContribution"]) do
        if (player:GetGUIDLow() == k) then
            if (MoneyReward > 0) then -- Handle Money Reward
                player:ModifyMoney(MoneyReward)
            end
            if (HonorReward > 0) then -- Handle Honor Reward
                player:ModifyHonorPoints(HonorReward)
            end
            if (ItemReward > 0) and (ItemRewardCount > 0) then -- Handle Item/Token Reward
                player:AddItem(ItemReward, ItemRewardCount)
            end
        end
    end
end
 
function ZoneBattles.ResetBattleCounter()
    -- Reset battle variables
    ZoneBattles["BattleContribution"] = {};
    ZoneBattles[0] = 0;
    ZoneBattles[1] = 0;
    ZoneBattles["BattleInProgress"] = true;
    
    SendWorldMessage("百团大战 "..ZoneBattles["BattleZone"][1].." 已经开始！")
    SummonAlert()

    for _, v in pairs(GetPlayersInMap(ZoneBattles["BattleZone"][2])) do
        if (v:GetZoneId() == ZoneBattles["BattleZone"][3]) then
            v:UpdateWorldState(2313, ZoneBattles[0]) -- Reset Alliance score when battle resets
            v:UpdateWorldState(2314, ZoneBattles[1]) -- Reset Horde score when battle resets
        end
    end
end

function SummonAlert()
    if(ZoneBattles["BattleInProgress"] == false) then return end
    local players = GetPlayersInWorld()
    if(players) then
        for k, player in ipairs(players) do
            player:GossipComplete()
            player:GossipClearMenu()
            player:GossipMenuAddItem(30, "百团大战已经开始", 0, 1, false, "|TInterface/FlavorImages/BloodElfLogo-small:64:64:0:-30|t\n \n \n \n \n \n百团大战"..ZoneBattles["BattleZone"][1].."现在已经开始！\n\n按[接受]直接传送进入战场。\n\n或者稍后通过传送宝石进入战场。")
            player:GossipSendMenu(100, player, 1999)
        end
    end
    CreateLuaEvent(SummonAlert, ZoneBattles["AlertCooldown"]*60*1000, 1)
end

function SummonAlertConfirm(event, player, object, sender, intid, code)
    if(ZoneBattles["BattleInProgress"] == true) then
        local teamId = player:GetTeam()
        local mapId = ZoneBattles["BattleZone"][2]
        local x = ZoneBattles["location"][teamId][1]
        local y = ZoneBattles["location"][teamId][2]
        local z = ZoneBattles["location"][teamId][3]
        local o = ZoneBattles["location"][teamId][4]
        player:Teleport(mapId, x, y, z, o)
    else
        player:SendNotification("已经结束，请等待下一次开始。")
    end
end

function ZoneBattles.OnEnterArea(event, player, newZone, newArea)
    if (player:GetMapId() == ZoneBattles["BattleZone"][2]) and (player:GetZoneId() == ZoneBattles["BattleZone"][3]) then
        player:InitializeWorldState(1377, 1, 0, 1) -- Initialize world state, score 0/0
        player:UpdateWorldState(2317, ZoneBattles["MaxScore"]) -- Sets correct MaxScore
        player:UpdateWorldState(2313, ZoneBattles[0]) -- Set correct Alliance score
        player:UpdateWorldState(2314, ZoneBattles[1]) -- Set correct Horde score
    end
end
 
function ZoneBattles.OnPvPKill(event, killer, killed)
    if ((killer:GetMapId() and killed:GetMapId()) == ZoneBattles["BattleZone"][2]) and ((killer:GetZoneId() and killed:GetZoneId()) == ZoneBattles["BattleZone"][3]) then
        local Team = killer:GetTeam()

        if ZoneBattles[0] < ZoneBattles["MaxScore"] and ZoneBattles[1] < ZoneBattles["MaxScore"] then
            if not ZoneBattles["BattleContribution"][killer:GetGUIDLow()] then
                ZoneBattles["BattleContribution"][killer:GetGUIDLow()] = true; -- Make sure player has contributed to the battle.
            end

            ZoneBattles[Team] = ZoneBattles[Team] + 1;

            for _, v in pairs(GetPlayersInMap(ZoneBattles["BattleZone"][2])) do
                if v:GetZoneId() == ZoneBattles["BattleZone"][3] then
                    v:UpdateWorldState(2313+Team, ZoneBattles[Team])
                end
            end
        end
        if ZoneBattles["BattleInProgress"] == true and ZoneBattles[Team] == ZoneBattles["MaxScore"] then
            ZoneBattles["BattleInProgress"] = false;
            for _, v in pairs(GetPlayersInMap(ZoneBattles["BattleZone"][2])) do
                if v:GetZoneId() == ZoneBattles["BattleZone"][3] then
                    if(v:GetTeam() == Team) then
                        HandleReward(v,1)
                    else
                        HandleReward(v,0)
                    end

                end
            end
            SendWorldMessage(""..TeamAsString(Team).." 获得了"..ZoneBattles["BattleZone"][1].."战斗胜利！ 下一次百团大战将在 "..ZoneBattles["Cooldown"].." 分钟后开始！")
            CreateLuaEvent(ZoneBattles.ResetBattleCounter, ZoneBattles["Cooldown"]*60*1000, 1)
        end
    end
end

ZoneBattles.ResetBattleCounter()
RegisterPlayerEvent(27, ZoneBattles.OnEnterArea)
RegisterPlayerEvent(6, ZoneBattles.OnPvPKill)
RegisterPlayerGossipEvent(1999, 2, SummonAlertConfirm)

