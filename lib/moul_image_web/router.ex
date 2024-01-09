defmodule MoulImageWeb.Router do
  use MoulImageWeb, :router

  pipeline :image do
    plug :accepts, ["image/*"]
    plug MoulImageWeb.Plug.Validate, fields: ["path"], paths: ["/thumbnail"]
  end

  scope "/", MoulImageWeb do
    pipe_through :image

    get "/thumbnail", ImageController, :thumbnail
    get "/thumbhash", ImageController, :thumbhash
  end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:moul_image, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through [:fetch_session, :protect_from_forgery]

      live_dashboard "/dashboard", metrics: MoulImageWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
