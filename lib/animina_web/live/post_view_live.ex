defmodule AniminaWeb.PostViewLive do
  use AniminaWeb, :live_view

  alias Animina.Accounts.User
  alias Animina.GenServers.ProfileViewCredits
  alias Animina.Narratives.Post
  alias Phoenix.PubSub

  use Timex

  @impl true
  def mount(
        %{"slug" => slug, "username" => username, "year" => year, "day" => day, "month" => month},
        %{"language" => language} = _session,
        socket
      ) do
    if connected?(socket) && socket.assigns.current_user != nil do
      PubSub.subscribe(Animina.PubSub, "credits")
      PubSub.subscribe(Animina.PubSub, "messages")

      PubSub.subscribe(
        Animina.PubSub,
        "#{socket.assigns.current_user.id}"
      )
    end

    user = User.by_username!(username, not_found_error?: false)

    socket =
      if user == nil do
        socket
        |> assign(language: language)
        |> assign(post: nil)
        |> assign(active_tab: :home)
        |> assign(error: nil)
      else
        date = Timex.parse!("#{year}-#{month}-#{day}", "{YYYY}-{0M}-{D}")

        post =
          Post.by_slug_user_and_date!(slug, user.id, date,
            not_found_error?: false,
            load: [:user, :url]
          )

        socket
        |> assign(language: language)
        |> assign(post: post)
        |> assign(active_tab: :home)
        |> assign(error: nil)
      end

    {:ok, socket}
  end

  @impl true
  def handle_params(_params, _uri, socket) do
    socket =
      case socket.assigns.post do
        nil ->
          socket
          |> assign(page_title: gettext("Post not found"))

        _ ->
          socket
          |> assign(page_title: "#{socket.assigns.post.user.name} | #{socket.assigns.post.title}")
      end

    {:noreply, socket}
  end

  @impl true
  def handle_info({:display_updated_credits, credits}, socket) do
    current_user_credit_points =
      ProfileViewCredits.get_updated_credit_for_current_user(socket.assigns.current_user, credits)

    {:noreply,
     socket
     |> assign(current_user_credit_points: current_user_credit_points)}
  end

  @impl true
  def handle_info({:credit_updated, _updated_credit}, socket) do
    {:noreply, socket}
  end

  def handle_info({:user, current_user}, socket) do
    {:noreply, socket |> assign(:current_user, current_user)}
  end

  def handle_info({:new_message, message}, socket) do
    unread_messages = socket.assigns.unread_messages ++ [message]

    {:noreply,
     socket
     |> assign(unread_messages: unread_messages)
     |> assign(number_of_unread_messages: Enum.count(unread_messages))}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="py-4">
      <div :if={@post == nil} class="px-12 pb-8">
        <h1 class="text-2xl font-semibold dark:text-white">
          <%= gettext("Something went wrong. We couldn't find this post") %>
        </h1>
      </div>

      <div :if={@post != nil} class="px-12 pb-8 space-y-4">
        <.post_header
          post={@post}
          current_user={@current_user}
          edit_post_title={gettext("Edit post")}
          subtitle={"#{gettext("By")} #{@post.user.name}"}
        />

        <.post_body content={@post.content} />
      </div>
    </div>
    """
  end
end
