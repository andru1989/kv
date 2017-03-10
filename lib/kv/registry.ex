defmodule KV.Registry do
  use GenServer

  @doc """
  Starts a new GenServer passing 3 arguments:
  1 - The module where the server callbacks are implemented, in this case
  __MODULE__, meaning the current module.
  2 - The initialization arguments, in this case the atom :ok
  3 - A list of options which can be used to specify things like the name of
  the server. For now we pas an empty list
  """
  def start_link do
    GenServer.start_link(__MODULE__, :ok, [])
  end

  @doc """
  Looks up the bucket pid for `name` stored in `server`.

  Returns `{:ok, pid}` if the bucket exists, `:error` otherwise.
  """
  def lookup(server, name) do
    GenServer.call(server, {:lookup, name})
  end

  @doc """
  Ensures there is a bucket associated to the given `name` in `server`.
  """
  def create(server, name) do
    GenServer.cast(server, {:create, name})
  end

  @doc """
  Stops the registry.
  """
  def stop(server) do
    GenServer.stop(server)
  end

  # Server Callbacks

  @doc """
  Receives the argument given to GenServer.start_link/3 and returns
  {:ok, state}, where state is a new map
  """
  def init(:ok) do
    names = %{}
    refs  = %{}
    {:ok, {names, refs}}
  end

  @doc """
  handle_call/3 must be used for synchronous requests.
  This should be the default choice as waiting for the server reply is a
  useful backpressure mechanism.
  """
  def handle_call({:lookup, name}, _from, {names, _} = state) do
    {:reply, Map.fetch(names, name), state}
  end

  @doc """
  handle_cast/2 must be used for asynchronous requests, when you don’t care
  about a reply. A cast does not even guarantee the server has received the
  message and, for this reason, should be used sparingly.
  For example, the create/2 function we have defined in this chapter should
  have used call/2. We have used cast/2 for didactic purposes.
  """
  def handle_cast({:create, name}, {names, refs}) do
    if Map.has_key?(names, name) do
      {:noreply, {names, refs}}
    else
      {:ok, pid} = KV.Bucket.start_link
      ref        = Process.monitor(pid)
      refs       = Map.put(refs, ref, name)
      names      = Map.put(names, name, pid)
      {:noreply, {names, refs}}
    end
  end

  @doc """
  handle_info/2 must be used for all other messages a server may receive
  that are not sent via GenServer.call/2 or GenServer.cast/2,
  including regular messages sent with send/2.
  The monitoring :DOWN messages are such an example of this.
  """
  def handle_info({:DOWN, ref, :process, _pid, _reason}, {names, refs}) do
    {name, refs} = Map.pop(refs, ref)
    names = Map.delete(names, name)
    {:noreply, {names, refs}}
  end

  def handle_info(_msg, state) do
    {:noreply, state}
  end
end
