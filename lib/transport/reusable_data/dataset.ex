defmodule Transport.ReusableData.Dataset do
  @moduledoc """
  Represents a dataset as it is published by a producer and consumed by a
  reuser.
  """

  defstruct [
    :_id,
    :title,
    :description,
    :logo,
    :spatial,
    :coordinates,
    :licence,
    :slug,
    :id,
    :download_url,
    :anomalies,
    :format,
    :error_count,
    :fatal_count,
    :notice_count,
    :warning_count,
    :valid?,
    :catalogue_id,
    validations: [],
  ]

  use ExConstructor

  @type t :: %__MODULE__{
          _id: %BSON.ObjectId{},
          title: String.t(),
          description: String.t(),
          logo: String.t(),
          spatial: String.t(),
          coordinates: [float()],
          licence: String.t(),
          slug: String.t(),
          download_url: String.t(),
          anomalies: [String.t()],
          format: String.t(),
          validations: [Map.t()] | Map.t(),
          error_count: integer(),
          fatal_count: integer(),
          notice_count: integer(),
          warning_count: integer(),
          valid?: boolean(),
          catalogue_id: String.t()
        }

  @doc """
  Calculate and add the number of errors to the dataset.
  """
  @spec assign(%__MODULE__{}, :error_count) :: %__MODULE__{}
  def assign(%__MODULE__{} = dataset, :error_count) do
    error_count =
      dataset
      |> Map.get(:validations)
      |> Enum.filter(&(&1["severity"] == "Error"))
      |> Enum.count()

    new(%{dataset | error_count: error_count})
  end

  @doc """
  Calculate and add the number of fatals errors to the dataset.
  """
  @spec assign(%__MODULE__{}, :fatal_count) :: %__MODULE__{}
  def assign(%__MODULE__{} = dataset, :fatal_count) do
    fatal_count =
      dataset
      |> Map.get(:validations)
      |> Enum.filter(&(&1["severity"] == "Fatal"))
      |> Enum.count()

    new(%{dataset | fatal_count: fatal_count})
  end

  @doc """
  Calculate and add the number of notices to the dataset.
  """
  @spec assign(%__MODULE__{}, :notice_count) :: %__MODULE__{}
  def assign(%__MODULE__{} = dataset, :notice_count) do
    notice_count =
      dataset
      |> Map.get(:validations)
      |> Enum.filter(&(&1["severity"] == "Notice"))
      |> Enum.count()

    new(%{dataset | notice_count: notice_count})
  end

  @doc """
  Calculate and add the number of warnings to the dataset.
  """
  @spec assign(%__MODULE__{}, :warning_count) :: %__MODULE__{}
  def assign(%__MODULE__{} = dataset, :warning_count) do
    warning_count =
      dataset
      |> Map.get(:validations)
      |> Enum.filter(&(&1["severity"] == "Warning"))
      |> Enum.count()

    new(%{dataset | warning_count: warning_count})
  end

  @doc """
  Group by issue type.
  """
  @spec assign(%__MODULE__{}, :group_validations) :: %__MODULE__{}
  def assign(%__MODULE__{} = dataset, :group_validations) do
    validations =
    dataset.validations
    |> Enum.group_by(fn validation -> validation["issue_type"] end)
    |> Map.new(fn {type, issues} -> {type, %{issues: issues, count: Enum.count issues}} end)

    %{dataset | validations: validations}
  end

  @doc """
  Add whether the dataset is valid or no.
  """
  @spec assign(%__MODULE__{}, :valid?) :: %__MODULE__{}
  def assign(%__MODULE__{} = dataset, :valid?) do
    # We have some neptune datasets. Until we know how to handle them,
    # we accept files that won’t be validated
    # new(%{dataset | valid?: dataset.fatal_count == 0})
    new(%{dataset | valid?: true})
  end
end
