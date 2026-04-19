local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

if RunService:IsServer() then
	return {} :: DataServiceClient
end

local Signal = require(ReplicatedStorage.Packages.Signal)
local DataServiceUtils = require(script.Parent.DataServiceUtils)
local Data = require(script.Parent.Data)

type Signal<T> = Signal.Signal<T>
type Path = Data.Path

local waitSignal = Signal.new()

local DataServiceClient = {
	_data = nil :: Data.Data<any>?,
}

function DataServiceClient.init(self: DataServiceClient)
	local remote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("DataServiceRemote")
	self._remote = remote
	self._fetchRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("DataServiceFetchRemote")

	remote.OnClientEvent:Connect(function(action: number, ...)
		if action == DataServiceUtils.enums.actions.init then
			self:_initData(...)
		elseif action == DataServiceUtils.enums.actions.set then
			self:_onSet(...)
		elseif action == DataServiceUtils.enums.actions.arrayInsert then
			self:_onArrayInsert(...)
		elseif action == DataServiceUtils.enums.actions.arrayRemove then
			self:_onArrayRemove(...)
		end
	end)

	self:waitForData()
end

function DataServiceClient.fetch(self: DataServiceClient, path: Path?, dontSet: boolean?): any
	local value = self._fetchRemote:InvokeServer(path)
	if not dontSet and path then
		self._data:set(path, value)
	end
	return value
end

function DataServiceClient.get(self: DataServiceClient, path: Path?): any
	self:waitForData()
	return self._data:get(path)
end

function DataServiceClient.set(self: DataServiceClient, path: Path, value: any)
	self._data:set(path, value)
end

function DataServiceClient.update(self: DataServiceClient, path: Path, callback: (any) -> any): any
	return self._data:update(path, callback)
end

function DataServiceClient.arrayInsert(self: DataServiceClient, path: Path, value: any, index: number?)
	self._data:arrayInsert(path, value, index)
end

function DataServiceClient.arrayRemove(self: DataServiceClient, path: Path, index: number): any
	return self._data:arrayRemove(path, index)
end

function DataServiceClient.getChangedSignal(self: DataServiceClient, path: Path): Signal<any>
	return self._data:getChangedSignal(path)
end

function DataServiceClient.getIndexChangedSignal(self: DataServiceClient, path: Path): Signal<any>
	return self._data:getIndexChangedSignal(path)
end

function DataServiceClient.getArrayInsertedSignal(self: DataServiceClient, path: Path): Signal<any>
	return self._data:getArrayInsertedSignal(path)
end

function DataServiceClient.getArrayRemovedSignal(self: DataServiceClient, path: Path): Signal<any>
	return self._data:getArrayRemovedSignal(path)
end

function DataServiceClient.waitForData(self: DataServiceClient): any
	local data = self._data
	if data then
		return data
	end

	waitSignal:Wait()
	return self._data
end

function DataServiceClient._initData(self: DataServiceClient, data: any): ()
	assert(self._data == nil, "DataServiceClient: Data already initialized")
	self._data = Data.new(data)
	waitSignal:Fire()
end

function DataServiceClient._onSet(self: DataServiceClient, path: Path, value: any): ()
	if self._data then
		self._data:set(path, value)
	end
end

function DataServiceClient._onArrayInsert(self: DataServiceClient, path: Path, value: any, index: number?): ()
	if self._data then
		self._data:arrayInsert(path, value, index)
	end
end

function DataServiceClient._onArrayRemove(self: DataServiceClient, path: Path, index: number): ()
	if self._data then
		self._data:arrayRemove(path, index)
	end
end

export type DataServiceClient = typeof(DataServiceClient) & {
	_remote: RemoteEvent,
	_fetchRemote: RemoteFunction,
}

return DataServiceClient
