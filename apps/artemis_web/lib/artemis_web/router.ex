defmodule ArtemisWeb.Router do
  use ArtemisWeb, :router

  require Ueberauth

  pipeline :browser do
    plug :accepts, ["html", "csv"]
    plug :fetch_session
    plug :fetch_flash
    plug Phoenix.LiveView.Flash
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  pipeline :read_auth do
    plug :fetch_session
    plug Guardian.Plug.Pipeline, module: ArtemisWeb.Guardian, error_handler: ArtemisWeb.Guardian.ErrorHandler
    plug Guardian.Plug.VerifyHeader
    plug Guardian.Plug.VerifySession
    plug Guardian.Plug.LoadResource, allow_blank: true
  end

  pipeline :require_auth do
    plug ArtemisWeb.Plug.ClientCredentials
    plug ArtemisWeb.Plug.BroadcastRequest
    plug Guardian.Plug.EnsureAuthenticated
  end

  scope "/", ArtemisWeb do
    pipe_through :browser
    pipe_through :read_auth

    scope "/auth" do
      get "/new", AuthController, :new
      get "/:provider", AuthController, :request
      get "/:provider/callback", AuthController, :callback
      post "/:provider/callback", AuthController, :callback
      delete "/logout", AuthController, :delete
    end

    scope "/" do
      pipe_through :require_auth

      get "/", HomeController, :index

      resources "/docs", WikiPageController do
        resources "/comments", WikiPageCommentController, only: [:create, :edit, :update, :delete], name: :comment
        resources "/revisions", WikiRevisionController, only: [:index, :show, :delete], as: :revision
        put "/tags", WikiPageTagController, :update, as: :tag
      end

      get "/customers/event-logs", CustomerController, :index_event_log_list
      get "/customers/event-logs/:id", CustomerController, :index_event_log_details
      resources "/customers", CustomerController do
        get "/event-logs", CustomerController, :show_event_log_list, as: :event_log
        get "/event-logs/:id", CustomerController, :show_event_log_details, as: :event_log
      end

      get "/docs/:id/:slug", WikiPageController, :show
      resources "/event-logs", EventLogController, only: [:index, :show]
      resources "/http-request-logs", HttpRequestLogController, only: [:index, :show]
      resources "/features", FeatureController

      resources "/incidents", IncidentController, only: [:index, :show, :delete] do
        resources "/comments", IncidentCommentController, only: [:create, :edit, :update, :delete], name: :comment
        put "/tags", IncidentTagController, :update, as: :tag
      end

      resources "/on-call", OnCallController, only: [:index]
      resources "/permissions", PermissionController
      resources "/roles", RoleController
      resources "/search", SearchController, only: [:index]
      resources "/sessions", SessionController, only: [:index, :show]
      resources "/jobs", JobController
      resources "/tags", TagController

      resources "/users", UserController do
        resources "/anonymization", UserAnonymizationController, as: "anonymization", only: [:create]
        resources "/impersonation", UserImpersonationController, as: "impersonation", only: [:create]
      end
    end
  end
end
