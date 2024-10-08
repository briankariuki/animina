defmodule AniminaWeb.PotentialPartnerLive do
  use AniminaWeb, :live_view
  require Ash.Query

  alias Animina.Accounts.Credit
  alias Animina.Accounts.User
  alias Animina.GenServers.ProfileViewCredits
  alias Animina.GeoData.City
  alias AshPhoenix.Form
  alias Phoenix.PubSub

  @impl true
  def mount(_params, %{"language" => language} = _session, socket) do
    add_registration_bonus(socket, socket.assigns.current_user)

    if connected?(socket) do
      PubSub.subscribe(Animina.PubSub, "credits")
      PubSub.subscribe(Animina.PubSub, "messages")

      PubSub.subscribe(
        Animina.PubSub,
        "#{socket.assigns.current_user.username}"
      )
    end

    user =
      socket.assigns.current_user

    update_last_registration_page_visited(user, "/my/potential-partner")

    socket =
      socket
      |> assign(update_form: AshPhoenix.Form.for_update(user, :update) |> to_form())
      |> assign(city_name: City.by_zip_code!(user.zip_code))
      |> assign(current_user: user)
      |> assign(active_tab: :home)
      |> assign(language: language)
      |> assign(
        page_title:
          with_locale(language, fn ->
            gettext("Preferences for your future partner")
          end)
      )

    {:ok, socket}
  end

  defp add_registration_bonus(socket, user) do
    if !connected?(socket) && is_nil(user) == false do
      # Make sure that a user gets one but only one registration bonus.
      case Credit
           |> Ash.Query.filter(user_id: user.id)
           |> Ash.Query.filter(subject: "Registration bonus")
           |> Ash.read!() do
        [] ->
          Credit.create!(%{
            user_id: user.id,
            points: 100,
            subject: "Registration bonus"
          })

        _ ->
          nil
      end
    end
  end

  defp update_last_registration_page_visited(user, page) do
    {:ok, _} =
      User.update_last_registration_page_visited(user, %{last_registration_page_visited: page})
  end

  @impl true
  def handle_info({:display_updated_credits, credits}, socket) do
    current_user_credit_points =
      ProfileViewCredits.get_updated_credit_for_current_user(socket.assigns.current_user, credits)

    {:noreply,
     socket
     |> assign(current_user_credit_points: current_user_credit_points)}
  end

  def handle_info({:new_message, message}, socket) do
    unread_messages = socket.assigns.unread_messages ++ [message]

    {:noreply,
     socket
     |> assign(unread_messages: unread_messages)
     |> assign(number_of_unread_messages: Enum.count(unread_messages))}
  end

  @impl true
  def handle_info({:credit_updated, _updated_credit}, socket) do
    {:noreply, socket}
  end

  def handle_info({:user, current_user}, socket) do
    socket =
      socket
      |> assign(update_form: AshPhoenix.Form.for_update(current_user, :update) |> to_form())
      |> assign(city_name: City.by_zip_code!(current_user.zip_code))
      |> assign(current_user: current_user)

    if current_user.state in user_states_to_be_auto_logged_out() do
      {:noreply,
       socket
       |> push_navigate(to: "/auth/user/sign-out?auto_log_out=#{current_user.state}")}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("validate_user", %{"form" => form_params}, socket) do
    form = Form.validate(socket.assigns.update_form, form_params, errors: true)

    {:noreply, socket |> assign(update_form: form)}
  end

  @impl true
  def handle_event("update_user", %{"form" => form_params}, socket) do
    form = Form.validate(socket.assigns.update_form, form_params)

    case Form.errors(form) do
      [] ->
        current_user =
          User.by_id!(socket.assigns.current_user.id)
          |> User.update!(form_params)

        {:noreply,
         socket
         |> assign(current_user: current_user)
         |> push_navigate(to: "/my/profile-photo")}

      _ ->
        {:noreply, assign(socket, update_form: form)}
    end
  end

  defp user_states_to_be_auto_logged_out do
    [
      :under_investigation,
      :banned,
      :archived
    ]
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="px-5 space-y-5 dark:text-white">
      <h2 class="text-xl font-bold">
        <%= with_locale(@language, fn -> %>
          <%= gettext("Criteria for your new partner") %>
        <% end) %>
      </h2>
      <p>
        <%= with_locale(@language, fn -> %>
          <%= gettext("We will use this information to find suitable partners for you.") %>
        <% end) %>
      </p>
      <.form
        :let={f}
        for={@update_form}
        phx-submit="update_user"
        phx-change="validate_user"
        class="space-y-6"
      >
        <div>
          <div class="flex items-center justify-between">
            <label
              for="user_partner_gender"
              class="block text-sm font-medium leading-6 text-gray-900 dark:text-white"
            >
              <%= with_locale(@language, fn -> %>
                <%= gettext("Gender") %>
              <% end) %>
            </label>
          </div>
          <div class="mt-2" phx-no-format>

        <%
          item_code = "male"
          item_title = with_locale(@language, fn -> gettext("Male") end)
        %>
        <div class="flex items-center mb-4">
          <%= radio_button(f, :partner_gender, item_code,
            id: "partner_gender_" <> item_code,
            class: "h-4 w-4 border-gray-300 text-indigo-600 focus:ring-indigo-500",
            checked: true
          ) %>
          <%= label(f, :partner_gender, item_title,
            for: "partner_gender_" <> item_code,
            class: "ml-3 block text-sm font-medium dark:text-white text-gray-700"
          ) %>
        </div>

        <%
          item_code = "female"
          item_title = with_locale(@language, fn -> gettext("Female") end)
        %>
        <div class="flex items-center mb-4">
          <%= radio_button(f, :partner_gender, item_code,
            id: "partner_gender_" <> item_code,
            class: "h-4 w-4 border-gray-300 text-indigo-600 focus:ring-indigo-500"
          ) %>
          <%= label(f, :partner_gender, item_title,
            for: "partner_gender_" <> item_code,
            class: "ml-3 block text-sm font-medium dark:text-white text-gray-700"
          ) %>
        </div>

        <%
          item_code = "diverse"
          item_title = with_locale(@language, fn -> gettext("Diverse") end)
        %>
        <div class="flex items-center mb-4">
          <%= radio_button(f, :partner_gender, item_code,
            id: "partner_gender_" <> item_code,
            class: "h-4 w-4 border-gray-300 text-indigo-600 focus:ring-indigo-500"
          ) %>
          <%= label(f, :partner_gender, item_title,
            for: "partner_gender_" <> item_code,
            class: "ml-3 block text-sm dark:text-white font-medium text-gray-700"
          ) %>
        </div>
      </div>
        </div>

        <div class="grid gap-8 md:grid-cols-2">
          <div>
            <label
              for="form_minimum_partner_height"
              class="block text-sm font-medium leading-6 text-gray-900 dark:text-white"
            >
              <%= with_locale(@language, fn -> %>
                <%= gettext("Minimum height") %>
              <% end) %>
            </label>
            <div phx-feedback-for={f[:minimum_partner_height].name} class="mt-2">
              <%= select(
                f,
                :minimum_partner_height,
                [{with_locale(@language, fn -> gettext("doesn't matter") end), nil}] ++
                  Enum.map(140..210, &{"#{&1} cm", &1}),
                class:
                  "block w-full rounded-md border-0 py-1.5 text-gray-900 shadow-sm ring-1 ring-inset focus:ring-2 dark:bg-gray-700 dark:text-white focus:ring-inset phx-no-feedback:ring-gray-300 phx-no-feedback:focus:ring-indigo-600 sm:text-sm sm:leading-6 " <>
                    unless(
                      get_field_errors(f[:minimum_partner_height], :minimum_partner_height) == [],
                      do: "ring-red-600 focus:ring-red-600",
                      else: "ring-gray-300 focus:ring-indigo-600"
                    ),
                autofocus: true
              ) %>

              <.error :for={
                msg <- get_field_errors(f[:minimum_partner_height], :minimum_partner_height)
              }>
                <%= with_locale(@language, fn -> %>
                  <%= gettext("Minimum height") <> " " <> msg %>
                <% end) %>
              </.error>
            </div>
          </div>

          <div>
            <label
              for="form_maximum_partner_height"
              class="block text-sm font-medium leading-6 text-gray-900 dark:text-white"
            >
              <%= with_locale(@language, fn -> %>
                <%= gettext("Maximum height") %>
              <% end) %>
            </label>
            <div phx-feedback-for={f[:maximum_partner_height].name} class="mt-2">
              <%= select(
                f,
                :maximum_partner_height,
                [{with_locale(@language, fn -> gettext("doesn't matter") end), nil}] ++
                  Enum.map(140..210, &{"#{&1} cm", &1}),
                class:
                  "block w-full rounded-md border-0 py-1.5 text-gray-900 dark:bg-gray-700 dark:text-white shadow-sm ring-1 ring-inset focus:ring-2 focus:ring-inset phx-no-feedback:ring-gray-300 phx-no-feedback:focus:ring-indigo-600 sm:text-sm sm:leading-6 " <>
                    unless(
                      get_field_errors(f[:maximum_partner_height], :maximum_partner_height) == [],
                      do: "ring-red-600 focus:ring-red-600",
                      else: "ring-gray-300 focus:ring-indigo-600"
                    )
              ) %>

              <.error :for={
                msg <- get_field_errors(f[:maximum_partner_height], :maximum_partner_height)
              }>
                <%= with_locale(@language, fn -> %>
                  <%= gettext("Maximum height") <> " " <> msg %>
                <% end) %>
              </.error>
            </div>
          </div>
        </div>
        <div class="grid gap-8 md:grid-cols-2">
          <div>
            <label
              for="form_minimum_partner_age"
              class="block text-sm font-medium leading-6 text-gray-900 dark:text-white"
            >
              <%= with_locale(@language, fn -> %>
                <%= gettext("Minimum age") %>
              <% end) %>
            </label>
            <div phx-feedback-for={f[:minimum_partner_age].name} class="mt-2">
              <%= select(f, :minimum_partner_age, Enum.map(18..110, &{&1, &1}),
                prompt: with_locale(@language, fn -> gettext("doesn't matter") end),
                value: f[:minimum_partner_age].value,
                class:
                  "block w-full rounded-md border-0 py-1.5 text-gray-900 dark:bg-gray-700 dark:text-white shadow-sm ring-1 ring-inset focus:ring-2 focus:ring-inset phx-no-feedback:ring-gray-300 phx-no-feedback:focus:ring-indigo-600 sm:text-sm sm:leading-6 " <>
                    unless(get_field_errors(f[:minimum_partner_age], :minimum_partner_age) == [],
                      do: "ring-red-600 focus:ring-red-600",
                      else: "ring-gray-300 focus:ring-indigo-600"
                    )
              ) %>

              <.error :for={msg <- get_field_errors(f[:minimum_partner_age], :minimum_partner_age)}>
                <%= with_locale(@language, fn -> %>
                  <%= gettext("Minimum age") <> " " <> msg %>
                <% end) %>
              </.error>
            </div>
          </div>

          <div>
            <label
              for="form_maximum_partner_age"
              class="block text-sm font-medium leading-6 text-gray-900 dark:text-white"
            >
              <%= with_locale(@language, fn -> %>
                <%= gettext("Maximum age") %>
              <% end) %>
            </label>
            <div phx-feedback-for={f[:maximum_partner_age].name} class="mt-2">
              <%= select(f, :maximum_partner_age, Enum.map(18..110, &{&1, &1}),
                prompt: with_locale(@language, fn -> gettext("doesn't matter") end),
                class:
                  "block w-full rounded-md border-0 py-1.5 text-gray-900 dark:bg-gray-700 dark:text-white shadow-sm ring-1 ring-inset focus:ring-2 focus:ring-inset phx-no-feedback:ring-gray-300 phx-no-feedback:focus:ring-indigo-600 sm:text-sm sm:leading-6 " <>
                    unless(get_field_errors(f[:maximum_partner_age], :maximum_partner_age) == [],
                      do: "ring-red-600 focus:ring-red-600",
                      else: "ring-gray-300 focus:ring-indigo-600"
                    )
              ) %>

              <.error :for={msg <- get_field_errors(f[:maximum_partner_age], :maximum_partner_age)}>
                <%= with_locale(@language, fn -> %>
                  <%= gettext("Maximum age") <> " " <> msg %>
                <% end) %>
              </.error>
            </div>
          </div>
        </div>

        <div>
          <label
            for="form_search_range"
            class="block text-sm font-medium leading-6 text-gray-900 dark:text-white"
          >
            <%= with_locale(@language, fn -> %>
              <%= gettext("Search range") %>
            <% end) %>
            <span class="text-gray-400">
              (<%= with_locale(@language, fn -> %>
                <%= gettext("around") %>
              <% end) %>
              <%= @current_user.zip_code %> <%= @city_name.name %>)
            </span>
          </label>
          <div phx-feedback-for={f[:search_range].name} class="mt-2">
            <%= select(
              f,
              :search_range,
              [
                {"2 km", 2},
                {"5 km", 5},
                {"10 km", 10},
                {"20 km", 20},
                {"30 km", 30},
                {"50 km", 50},
                {"75 km", 75},
                {"100 km", 100},
                {"150 km", 150},
                {"200 km", 200},
                {"300 km", 300}
              ],
              prompt: with_locale(@language, fn -> gettext("doesn't matter") end),
              class:
                "block w-full rounded-md border-0 py-1.5 dark:bg-gray-700 dark:text-white text-gray-900 shadow-sm ring-1 ring-inset focus:ring-2 focus:ring-inset phx-no-feedback:ring-gray-300 phx-no-feedback:focus:ring-indigo-600 sm:text-sm sm:leading-6 " <>
                  unless(get_field_errors(f[:search_range], :search_range) == [],
                    do: "ring-red-600 focus:ring-red-600",
                    else: "ring-gray-300 focus:ring-indigo-600"
                  )
            ) %>

            <.error :for={msg <- get_field_errors(f[:search_range], :search_range)}>
              <%= with_locale(@language, fn -> %>
                <%= gettext("Search range") <> " " <> msg %>
              <% end) %>
            </.error>
          </div>
        </div>

        <div class="flex items-center gap-2 mb-4">
          <%= checkbox(f, :preapproved_communication_only,
            id: "preapproved_communication_only",
            class: "h-4 w-4 border-gray-300 text-indigo-600 focus:ring-indigo-500"
          ) %>
          <p>
            <%= with_locale(@language, fn -> %>
              <%= gettext("Only users who I liked can initiate a chat.") %>
            <% end) %>
          </p>
        </div>

        <div class="flex items-center gap-2 mb-4">
          <%= checkbox(f, :is_private,
            id: "is_private",
            class: "h-4 w-4 border-gray-300 text-indigo-600 focus:ring-indigo-500"
          ) %>
          <p>
            <%= with_locale(@language, fn -> %>
              <%= gettext("My profile is only visible for animina users.") %>
            <% end) %>
          </p>
        </div>

        <div>
          <%= submit(with_locale(@language, fn -> gettext("Save") end),
            class:
              "flex w-full justify-center rounded-md bg-indigo-600 px-3 py-1.5 text-sm font-semibold leading-6 text-white shadow-sm hover:bg-indigo-500 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-indigo-600"
          ) %>
        </div>
      </.form>
    </div>
    """
  end

  def cal_minimum_partner_height(user) do
    # This is not a scientific method. Don't start to argue with me
    # about this. The assumption is that women prefer taller men and
    # vice versa. Obviously, this is not true for everyone. But a good
    # 80% solution.
    case user.gender do
      "female" -> user.height
      _ -> nil
    end
  end

  def cal_maximum_partner_height(user) do
    case user.gender do
      "male" -> user.height
      _ -> nil
    end
  end

  def cal_minimum_partner_age(user) do
    user.age - 7
  end

  def cal_maximum_partner_age(user) do
    user.age + 7
  end

  def guess_partner_gender(user) do
    case user.gender do
      "male" -> "female"
      "female" -> "male"
      _ -> "diverse"
    end
  end

  defp get_field_errors(field, _name) do
    Enum.map(field.errors, &translate_error(&1))
  end
end
