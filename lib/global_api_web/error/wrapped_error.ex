defmodule GlobalApiWeb.WrappedError do
  defexception [:message, :status_code]

  @impl true
  def exception(%{message: message, status_code: status_code}) do
    %GlobalApiWeb.WrappedError{message: message, status_code: status_code}
  end

  @impl true
  def exception({message, status_code}) do
    %GlobalApiWeb.WrappedError{message: message, status_code: status_code}
  end
end
