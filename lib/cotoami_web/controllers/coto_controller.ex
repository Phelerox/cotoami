defmodule CotoamiWeb.CotoController do
  use CotoamiWeb, :controller
  require Logger
  import Cotoami.CotonomaService, only: [increment_timeline_revision: 1]
  alias Cotoami.{Coto, CotoService, CotonomaService, CotoGraphService}

  plug(:scrub_params, "coto" when action in [:create, :update])

  def action(conn, _) do
    apply(__MODULE__, action_name(conn), [conn, conn.params, conn.assigns.amishi])
  end

  @index_options ["exclude_pinned_graph", "exclude_posts_in_cotonoma"]

  def index(conn, %{"page" => page} = params, amishi) do
    page_index = String.to_integer(page)
    options = get_flags_in_params(params, @index_options)
    paginated_results = CotoService.all_by_amishi(amishi, page_index, options)
    render(conn, "paginated_cotos.json", paginated_results)
  end

  def random(conn, params, amishi) do
    options = get_flags_in_params(params, @index_options)
    render(conn, "cotos.json", cotos: CotoService.random_by_amishi(amishi, options))
  end

  def search(conn, %{"query" => query}, amishi) do
    render(conn, "cotos.json", cotos: CotoService.search(query, amishi))
  end

  def create(
        conn,
        %{
          "coto" => %{
            "content" => content,
            "summary" => summary,
            "cotonoma_id" => cotonoma_id
          }
        },
        amishi
      ) do
    coto = CotoService.create!(amishi, content, summary, cotonoma_id)
    on_coto_created(conn, coto, amishi)
    render(conn, "created.json", coto: coto)
  end

  def update(conn, %{"id" => id, "coto" => coto_params}, amishi) do
    {:ok, coto} =
      Repo.transaction(fn ->
        case CotoService.update!(id, coto_params, amishi) do
          %Coto{posted_in: nil} = coto ->
            coto

          %Coto{posted_in: posted_in} = coto ->
            %{coto | posted_in: increment_timeline_revision(posted_in)}
        end
      end)

    broadcast_coto_update(coto, amishi, conn.assigns.client_id)

    if coto.as_cotonoma do
      broadcast_cotonoma_update(coto.cotonoma, amishi, conn.assigns.client_id)
    end

    render(conn, "coto.json", coto: coto)
  rescue
    e in Ecto.ConstraintError -> send_resp_by_constraint_error(conn, e)
  end

  def cotonomatize(conn, %{"id" => id}, amishi) do
    case CotoService.get_by_amishi(id, amishi) do
      %Coto{as_cotonoma: false} = coto ->
        {:ok, coto} = do_cotonomatize(coto, amishi)
        broadcast_cotonomatize(coto.cotonoma, amishi, conn.assigns.client_id)
        render(conn, "coto.json", coto: coto)

      # Fix inconsistent state caused by the cotonomatizing-won't-affect-graph bug
      %Coto{as_cotonoma: true} = coto ->
        CotoGraphService.sync(Bolt.Sips.conn(), coto)
        render(conn, "coto.json", coto: coto)

      _ ->
        send_resp(conn, :not_found, "")
    end
  rescue
    e in Ecto.ConstraintError -> send_resp_by_constraint_error(conn, e)
  end

  defp do_cotonomatize(coto, amishi) do
    Repo.transaction(fn ->
      case CotonomaService.cotonomatize!(coto, amishi) do
        %Coto{posted_in: nil} = coto ->
          coto

        %Coto{posted_in: posted_in} = coto ->
          %{coto | posted_in: increment_timeline_revision(posted_in)}
      end
    end)
  end

  def delete(conn, %{"id" => id}, amishi) do
    {:ok, _} =
      Repo.transaction(fn ->
        coto = CotoService.delete!(id, amishi)

        if coto.posted_in do
          increment_timeline_revision(coto.posted_in)
        end

        coto
      end)

    broadcast_delete(id, amishi, conn.assigns.client_id)
    send_resp(conn, :no_content, "")
  end
end
