--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

if RunService:IsClient() then
	return {} :: DataServiceServer
end

local Signal = require(ReplicatedStorage.Packages.Signal)
local ProfileStore = if RunService:IsServer() then require(ReplicatedStorage.Packages.ProfileStore) else nil :: any
local Data = require(script.Parent.Data)
local DataServiceUtils = require(script.Parent.DataServiceUtils)

local DATA_PREFIX = "PLAYER_"
local DEFAULT_PROFILE_STORE_INDEX = "Default"

type Path = Data.Path
type Signal<T> = Signal.Signal<T>

type MessageData = {
	key: string,
	data: { any },
}

type DataTemplate = { [string]: any }

type DataOptions = {
	template: any,
	useMock: boolean?,
	viewedUserId: number?,
	overridenUserId: number?,
	dontSave: boolean?,
	resetData: boolean?,
	profileStoreIndex: string?,
	profileStoreDataPrefix: string?,
}

type Profile = ProfileStore.Profile<any>

local DataServiceServer = {
	_profiles = {} :: { [Player]: Profile },
	_data = {} :: { [Player]: Data.Data<any> },
	_waitSignals = {} :: { [Player]: Signal.Signal<any> },
	_globalCallbacks = {} :: { [string]: (player: Player, { any }) -> boolean? },
	_globalCallbackAdded = Signal.new() :: Signal.Signal<string>,
	_removalFunctions = {} :: { (player: Player, data: any) -> () },
	options = {} :: DataOptions,
}

local function storeCancel(player: Player)
	return {
		Cancel = function()
			return player.Parent ~= Players
		end,
	}
end

function DataServiceServer.init(self: DataServiceServer, options: DataOptions): ()
	assert(RunService:IsServer(), "DataServiceServer can only be used on the server.")
	assert(not self.playerStore, "DataServiceServer has already been initialized.")
	self.options = options
	self.playerStore = ProfileStore.New(options.profileStoreIndex or DEFAULT_PROFILE_STORE_INDEX, options.template)

	local remote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("DataServiceRemote")
	self._remote = remote

	local fetchRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("DataServiceFetchRemote")
	fetchRemote.OnServerInvoke = function(player: Player, path: Path?)
		local data = self._data[player]
		if not data then
			return nil
		end
		return data:get(path)
	end

	for _, player: Player in Players:GetPlayers() do
		task.spawn(function()
			self:_playerAdded(player)
		end)
	end

	Players.PlayerAdded:Connect(function(player: Player)
		self:_playerAdded(player)
	end)

	Players.PlayerRemoving:Connect(function(player: Player)
		self:_playerRemoving(player)
	end)
end

function DataServiceServer._playerAdded(self: DataServiceServer, player: Player): ()
	local userId = self.options.overridenUserId or self.options.viewedUserId or player.UserId
	local index = self:_getProfileKey(userId)

	if self.options.resetData and not self.options.viewedUserId then
		self.playerStore:RemoveAsync(index)
	end

	local profile: Profile = if self.options.useMock
		then self.playerStore.Mock:StartSessionAsync(index, storeCancel(player))
		elseif self.options.viewedUserId or self.options.dontSave then self.playerStore:GetAsync(index)
		else self.playerStore:StartSessionAsync(index, storeCancel(player))

	if not profile then
		player:Kick(`Profile load fail - Please rejoin`)
		return
	end

	profile:AddUserId(userId)
	profile:Reconcile()
	profile.OnSessionEnd:Connect(function()
		self._profiles[player] = nil
		player:Kick(`Profile session end - Please rejoin`)
	end)

	if not player:IsDescendantOf(Players) then
		profile:EndSession()
		return
	end

	self._profiles[player] = profile
	self:_initPlayer(player, profile.Data)

	if not player:IsDescendantOf(Players) then
		profile:EndSession()
		return
	end

	profile:MessageHandler(function(messageData: MessageData, processed: () -> ())
		local cb = self._globalCallbacks[messageData.key]
		if cb then
			if cb(player, messageData.data) ~= false then
				processed()
			end
			return
		end

		local waitConnection
		waitConnection = self._globalCallbackAdded:Connect(function(key: string)
			if key ~= messageData.key then
				return
			end
			if self._globalCallbacks[messageData.key](player, messageData.data) ~= false then
				processed()
			end
			waitConnection:Disconnect()
		end)
	end)
end

function DataServiceServer._getProfileKey(self: DataServiceServer, userId: number | string): string
	return (self.options.profileStoreDataPrefix or DATA_PREFIX) .. tostring(userId)
end

function DataServiceServer._playerRemoving(self: DataServiceServer, player: Player): ()
	local profile = self._profiles[player]

	if not profile then
		return
	end

	for _, fn in self._removalFunctions do
		local success, err: any? = pcall(fn, player, profile.Data)
		if not success then
			warn(err or "Error in removal function for " .. player.Name)
		end
	end

	profile:EndSession()
	self._profiles[player] = nil

	local waitSignal = self._waitSignals[player]
	if waitSignal then
		waitSignal:Destroy()
		self._waitSignals[player] = nil
	end

	local data = self._data[player]
	if data then
		data:destroy()
		self._data[player] = nil
	end
end

function DataServiceServer._initPlayer(self: DataServiceServer, player: Player, data: any): ()
	self._data[player] = Data.new(data)
	self:onPlayerInit(player, data)
	self._remote:FireClient(player, DataServiceUtils.enums.actions.init, data)

	local waitSignal = self._waitSignals[player]
	if waitSignal then
		waitSignal:Fire()
		waitSignal:Destroy()
		self._waitSignals[player] = nil
	end
end

function DataServiceServer.onPlayerInit(_self: DataServiceServer, _player: Player, _data: any): ()
	-- Override this method to run logic when a player's data initializes.
	-- Called after data loads but before it is sent to the client.
end

function DataServiceServer.resetData(self: DataServiceServer, player: Player): ()
	local index = self:_getProfileKey(player.UserId)
	self:_playerRemoving(player)
	self.playerStore:RemoveAsync(index)
	player:Kick("Your data has been reset. Please rejoin.")
end

function DataServiceServer.hasProfile(self: DataServiceServer, player: Player): boolean
	return self._profiles[player] ~= nil
end

function DataServiceServer.getProfile(self: DataServiceServer, player: Player): Profile
	assert(self._profiles[player], "Profile does not exist for " .. player.Name)
	return self._profiles[player]
end

function DataServiceServer.asyncGetProfile(self: DataServiceServer, userId: number | string): Profile?
	local profileKey = DATA_PREFIX .. tostring(userId)
	return self.playerStore:GetAsync(profileKey)
end

function DataServiceServer.waitForData(self: DataServiceServer, player: Player): Data.Data<any>
	local data = self._data[player]
	if data then
		return data
	end

	local waitSignal = self._waitSignals[player]
	if not waitSignal then
		waitSignal = Signal.new()
		self._waitSignals[player] = waitSignal
	end

	waitSignal:Wait()
	return self._data[player]
end

function DataServiceServer.get(self: DataServiceServer, player: Player, path: Path?): any
	return self._data[player]:get(path)
end

function DataServiceServer.set(
	self: DataServiceServer,
	player: Player,
	path: Path,
	value: any,
	dontReplicate: boolean?
)
	if not dontReplicate then
		self._remote:FireClient(player, DataServiceUtils.enums.actions.set, path, value)
	end

	self._data[player]:set(path, value)
end

function DataServiceServer.update(
	self: DataServiceServer,
	player: Player,
	path: Path,
	callback: (any) -> any,
	dontReplicate: boolean?
): any
	local value = self._data[player]:update(path, callback)

	if not dontReplicate then
		self._remote:FireClient(player, DataServiceUtils.enums.actions.set, path, value)
	end

	return value
end

function DataServiceServer.arrayInsert(
	self: DataServiceServer,
	player: Player,
	path: Path,
	value: any,
	index: number?,
	dontReplicate: boolean?
)
	if not dontReplicate then
		self._remote:FireClient(player, DataServiceUtils.enums.actions.arrayInsert, path, value, index)
	end

	self._data[player]:arrayInsert(path, value, index)
end

function DataServiceServer.arrayRemove(
	self: DataServiceServer,
	player: Player,
	path: Path,
	index: number,
	dontReplicate: boolean?
): any
	local value = self._data[player]:arrayRemove(path, index)

	if not dontReplicate then
		self._remote:FireClient(player, DataServiceUtils.enums.actions.arrayRemove, path, index)
	end

	return value
end

function DataServiceServer.getChangedSignal(self: DataServiceServer, player: Player, path: Path): Signal<any>
	return self._data[player]:getChangedSignal(path)
end

function DataServiceServer.getIndexChangedSignal(self: DataServiceServer, player: Player, path: Path): Signal<any>
	return self._data[player]:getIndexChangedSignal(path)
end

function DataServiceServer.getArrayInsertedSignal(self: DataServiceServer, player: Player, path: Path): Signal<any>
	return self._data[player]:getArrayInsertedSignal(path)
end

function DataServiceServer.getArrayRemovedSignal(self: DataServiceServer, player: Player, path: Path): Signal<any>
	return self._data[player]:getArrayRemovedSignal(path)
end

function DataServiceServer.addPlayerRemovingCallback(
	self: DataServiceServer,
	fn: (player: Player, data: any) -> ()
): () -> ()
	table.insert(self._removalFunctions, fn)
	return function()
		local index = table.find(self._removalFunctions, fn)
		if index then
			table.remove(self._removalFunctions, index)
		end
	end
end

function DataServiceServer.sendGlobalMessage(
	self: DataServiceServer,
	key: string,
	userId: number | string,
	data: { any }
): boolean
	local messageData: MessageData = { key = key, data = data }
	return self.playerStore:MessageAsync(self:_getProfileKey(userId), messageData)
end

function DataServiceServer.addGlobalCallback(
	self: DataServiceServer,
	key: string,
	cb: (player: Player, { any }) -> boolean?
): ()
	assert(self._globalCallbacks[key] == nil, "Global callback already exists for key: " .. key)
	self._globalCallbacks[key] = cb
	self._globalCallbackAdded:Fire(key)
end

export type DataServiceServer = typeof(DataServiceServer) & {
	playerStore: ProfileStore.ProfileStore<any>,
	_remote: RemoteEvent,
}

return DataServiceServer
