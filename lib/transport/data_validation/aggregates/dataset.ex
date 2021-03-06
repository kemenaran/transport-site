defmodule Transport.DataValidation.Aggregates.Dataset do
  @moduledoc """
  A dataset is a container for dataset validations.
  """

  defstruct [:uuid, :download_url, :validations]

  use GenServer
  use ExConstructor
  alias Transport.DataValidation.Aggregates.Dataset
  alias Transport.DataValidation.Commands.{CreateDataset, ValidateDataset}
  alias Transport.DataValidation.Events.{DatasetCreated, DatasetUpdated, DatasetValidated}
  alias Transport.DataValidation.Queries.FindDataset
  alias Transport.DataValidation.Repo.Dataset, as: Repo
  alias Transport.DataValidation.Supervisor

  @registry :dataset_registry
  @timeout 60_000

  @type t :: %__MODULE__{
          uuid: String.t(),
          download_url: String.t(),
          validations: [Dataset.Validation.t()]
        }

  def start_link(download_url) when is_binary(download_url) do
    GenServer.start_link(
      __MODULE__,
      %__MODULE__{download_url: download_url},
      name: via_tuple(download_url)
    )
  end

  def execute(%FindDataset{} = query) do
    query.download_url
    |> registry_lookup
    |> GenServer.call({:find_dataset, query}, @timeout)
  end

  def execute(%CreateDataset{} = command) do
    command.download_url
    |> registry_lookup
    |> GenServer.call({:dataset_created, DatasetCreated.new(command)}, @timeout)
  end

  def execute(%ValidateDataset{} = command) do
    with pid <- registry_lookup(command.download_url),
         dataset_validated <- DatasetValidated.new(command),
         {:ok, dataset} <- GenServer.call(pid, {:dataset_validated, dataset_validated}, @timeout),
         dataset_updated <- DatasetUpdated.new(dataset),
         :ok <- GenServer.cast(pid, {:dataset_updated, dataset_updated}) do
      {:ok, dataset}
    else
      {:error, error} -> {:error, error}
    end
  end

  def init(%__MODULE__{} = dataset) do
    {:ok, dataset}
  end

  def handle_call(
        {:find_dataset, %FindDataset{} = query},
        _from,
        %__MODULE__{uuid: nil} = dataset
      ) do
    case Repo.read(query) do
      {:ok, dataset} -> {:reply, {:ok, dataset}, dataset}
      {:error, error} -> {:reply, {:error, error}, dataset}
    end
  end

  def handle_call({:find_dataset, %FindDataset{}}, _from, %__MODULE__{} = dataset) do
    {:reply, {:ok, dataset}, dataset}
  end

  def handle_call(
        {:dataset_created, %DatasetCreated{} = event},
        _from,
        %__MODULE__{uuid: nil} = dataset
      ) do
    case Repo.project(event) do
      {:ok, dataset} -> {:reply, {:ok, dataset}, dataset}
      {:error, error} -> {:reply, {:error, error}, dataset}
    end
  end

  def handle_call({:dataset_created, %DatasetCreated{}}, _from, %__MODULE__{} = dataset) do
    {:reply, {:ok, dataset}, dataset}
  end

  def handle_call(
        {:dataset_validated, %DatasetValidated{} = event},
        _from,
        %__MODULE__{} = dataset
      ) do
    case Repo.project(event) do
      {:ok, validations} ->
        dataset = %Dataset{dataset | validations: validations}
        {:reply, {:ok, dataset}, dataset}

      {:error, error} ->
        {:reply, {:error, error}, dataset}
    end
  end

  def handle_cast({:dataset_updated, %DatasetUpdated{} = event}, %__MODULE__{} = dataset) do
    case Repo.project(event) do
      :ok -> {:noreply, dataset}
      {:error, error} -> {:stop, error, dataset}
    end
  end

  # private

  defp via_tuple(download_url) when is_binary(download_url) do
    {:via, Registry, {@registry, download_url}}
  end

  defp registry_lookup(download_url) when is_binary(download_url) do
    case Registry.lookup(@registry, download_url) do
      [{pid, _}] ->
        pid

      [] ->
        {:ok, pid} = Supervisor.start_dataset(download_url)
        pid
    end
  end
end
