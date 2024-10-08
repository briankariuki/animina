defmodule AniminaWeb.ReviewReportLive do
  use AniminaWeb, :live_view

  alias Animina.Accounts
  alias Animina.Accounts.Points
  alias Animina.Accounts.Report
  alias Animina.GenServers.ProfileViewCredits
  alias Animina.Markdown
  alias AshPhoenix.Form
  alias Phoenix.PubSub

  @impl true
  def mount(%{"id" => id}, %{"language" => language} = _session, socket) do
    if connected?(socket) do
      PubSub.subscribe(Animina.PubSub, "messages")

      PubSub.subscribe(
        Animina.PubSub,
        "#{socket.assigns.current_user.id}"
      )

      Phoenix.PubSub.subscribe(
        Animina.PubSub,
        "user_flag:created:#{socket.assigns.current_user.id}"
      )
    end

    report = Report.by_id!(id, actor: socket.assigns.current_user)

    form =
      report
      |> Form.for_update(:update,
        domain: Accounts,
        as: "report",
        forms: [],
        actor: socket.assigns.current_user
      )
      |> to_form()

    socket =
      socket
      |> assign(active_tab: :reports)
      |> assign(:language, language)
      |> assign(:report, report)
      |> assign(:page_title, gettext("Review  Report"))
      |> assign(form: form)

    {:ok, socket}
  end

  @impl true
  def handle_event("validate", %{"report" => report}, socket) do
    form = Form.validate(socket.assigns.form, report, errors: true)

    {:noreply,
     socket
     |> assign(:form, form)}
  end

  def handle_event(
        "submit",
        %{"report" => %{"admin_id" => _, "internal_memo" => _, "state" => _} = report},
        socket
      ) do
    form = Form.validate(socket.assigns.form, report)

    case Report.review(
           socket.assigns.report,
           report
         ) do
      {:ok, _report} ->
        {:noreply,
         socket
         |> assign(:errors, [])
         |> put_flash(
           :info,
           with_locale(socket.assigns.language, fn -> gettext("Report reviewed successfully.") end)
         )
         |> push_navigate(to: ~p"/admin/reports/pending")}

      _ ->
        {:noreply, socket |> assign(:form, form)}
    end
  end

  @impl true
  def handle_info({:display_updated_credits, credits}, socket) do
    current_user_credit_points =
      ProfileViewCredits.get_updated_credit_for_current_user(socket.assigns.current_user, credits)
      |> Points.humanized_points()

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

  def handle_info({:user, current_user}, socket) do
    if current_user.state in user_states_to_be_auto_logged_out() do
      {:noreply,
       socket
       |> push_navigate(to: "/auth/user/sign-out?auto_log_out=#{current_user.state}")}
    else
      {:noreply,
       socket
       |> assign(:current_user, current_user)}
    end
  end

  defp user_states_to_be_auto_logged_out do
    [
      :under_investigation,
      :banned,
      :archived
    ]
  end

  defp format_date(date) do
    Timex.format!(date, "{WDshort}, {Mshort} {D}, {YYYY}")
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <p class="dark:text-white text-black  text-xl">
        <%= with_locale(@language, fn -> %>
          <%= gettext("Review Report") %>
        <% end) %>
      </p>

      <div class="flex flex-col gap-2">
        <div class="flex flex-col  text-black dark:text-white  border-b-[0.3px] border-black outline-offset-2 dark:border-white gap-1">
          <div class="w-[100%]  flex justify-between items-center">
            <p>
              <%= format_date(@report.created_at) %>
            </p>

            <p class="capitalize">
              <%= @report.state %>
            </p>
          </div>

          <div class="w-[100%]  flex justify-between items-center">
            <div class="flex flex-col gap-1">
              <p class="italic"><%= gettext("Accuser") %></p>
              <.link class="text-blue-500 underline" navigate={"/#{@report.accuser.username}"}>
                <%= @report.accuser.username %>
              </.link>
            </div>

            <div class="flex flex-col justify-end items-end gap-1">
              <p class="italic"><%= gettext("Accused") %></p>
              <.link class="text-blue-500 underline" navigate={"/#{@report.accused.username}"}>
                <%= @report.accused.username %>
              </.link>
            </div>
          </div>
        </div>
        <div class="dark:text-white flex flex-col gap-1  text-black">
          <p class="font-medium ">
            <%= with_locale(@language, fn -> %>
              <%= gettext("Description :") %>
            <% end) %>
          </p>
          <p class="text-gray-900 text-sm ">
            <%= Markdown.format(@report.description) %>
          </p>
        </div>
      </div>

      <.form
        :let={f}
        id="update-report-form"
        for={@form}
        class="space-y-3 group mt-4"
        phx-change="validate"
        phx-submit="submit"
      >
        <p class="dark:text-white font-medium text-black">
          <%= with_locale(@language, fn -> %>
            <%= gettext("Your Review :") %>
          <% end) %>
        </p>
        <%= hidden_input(f, :admin_id, value: @current_user.id) %>
        <div phx-feedback-for={f[:state].name} class="">
          <label for="report_state" class="block  font-medium leading-6 text-gray-900 dark:text-white">
            <%= with_locale(@language, fn -> %>
              <%= gettext("State of the Report") %>
            <% end) %>
          </label>
          <%= select(
            f,
            :state,
            [:accepted, :denied],
            prompt: with_locale(@language, fn -> gettext("Select a state") end),
            class:
              "block w-full rounded-md border-0 py-1.5 text-gray-900 dark:bg-gray-700 dark:text-white shadow-sm ring-1 ring-inset placeholder:text-gray-400 focus:ring-2 focus:ring-inset sm:text-sm  phx-no-feedback:ring-gray-300 phx-no-feedback:focus:ring-indigo-600 sm:leading-6  ring-gray-300 focus:ring-indigo-600",
            placeholder:
              gettext(
                "Use normal text or the Markdown format to write your internal_memo. You can use **bold**, *italic*, ~line-through~, [links](https://example.com) and more. Each post can be up to 8,192 characters long. Please do write multiple posts to share your thoughts."
              ),
            value: f[:state].value,
            type: :text,
            required: true,
            "phx-debounce": "200"
          ) %>
        </div>

        <div>
          <label
            for="report_internal_memo"
            class="block  font-medium leading-6 text-gray-900 dark:text-white"
          >
            <%= with_locale(@language, fn -> %>
              <%= gettext("Write Internal Memo") %>
            <% end) %>
          </label>

          <div phx-feedback-for={f[:internal_memo].name} class="mt-2">
            <%= textarea(
              f,
              :internal_memo,
              class:
                "block w-full rounded-md border-0 py-1.5 text-gray-900 dark:bg-gray-700 dark:text-white shadow-sm ring-1 ring-inset placeholder:text-gray-400 focus:ring-2 focus:ring-inset sm:text-sm  phx-no-feedback:ring-gray-300 phx-no-feedback:focus:ring-indigo-600 sm:leading-6 ring-gray-300 focus:ring-indigo-600 ",
              placeholder:
                with_locale(@language, fn ->
                  gettext(
                    "Use normal text or the Markdown format to write your internal memo. You can use **bold**, *italic*, ~line-through~, [links](https://example.com) and more. Each post can be up to 8,192 characters long."
                  )
                end),
              value: f[:internal_memo].value,
              rows: 12,
              type: :text,
              required: true,
              "phx-debounce": "200",
              maxlength: "8192"
            ) %>
          </div>
        </div>

        <div>
          <%= submit(with_locale(@language, fn -> gettext("Review Report") end),
            class:
              "flex w-full justify-center rounded-md bg-indigo-600 px-3 py-1.5 text-sm font-semibold leading-6 text-white shadow-sm hover:bg-indigo-500 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-indigo-600 " <>
                unless(@form.source.source.valid? == false,
                  do: "",
                  else: "opacity-40 cursor-not-allowed hover:bg-blue-500 active:bg-blue-500"
                ),
            disabled: @form.source.source.valid? == false
          ) %>
        </div>
      </.form>
    </div>
    """
  end
end
