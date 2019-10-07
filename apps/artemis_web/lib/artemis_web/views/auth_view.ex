defmodule ArtemisWeb.AuthView do
  use ArtemisWeb, :view

  def list_auth_providers(conn) do
    state = Map.get(conn.query_params, "redirect")

    available_providers = %{
      "system_user" => %{
        title: "Log in as System User",
        link: Routes.auth_path(conn, :callback, "system_user", state: state)
      },
      "w3id" => %{
        title: "Log in with IBM W3ID",
        link: Routes.auth_path(conn, :request, "w3id", state: state)
      }
    }

    enabled_providers =
      :artemis_web
      |> Application.get_env(:auth_providers, [])
      |> Keyword.get(:enabled, "")
      |> String.split(",")

    available_providers
    |> Map.take(enabled_providers)
    |> Enum.map(fn {_key, value} -> value end)
  end
end
