defmodule ArtemisWeb.ViewHelper.Tables do
  use Phoenix.HTML

  import Phoenix.HTML.Tag

  @default_delimiter ","

  @doc """
  Generates empty table row if no records match
  """
  def render_table_row_if_empty(records, options \\ [])

  def render_table_row_if_empty(%{entries: entries}, options), do: render_table_row_if_empty(entries, options)

  def render_table_row_if_empty(records, options) when length(records) == 0 do
    message = Keyword.get(options, :message, "No records found")

    Phoenix.View.render(ArtemisWeb.LayoutView, "table_row_if_empty.html", message: message)
  end

  def render_table_row_if_empty(_records, _options), do: nil

  @doc """
  Render sortable table header
  """
  def sortable_table_header(conn, value, label, delimiter \\ @default_delimiter) do
    path = order_path(conn, value, delimiter)
    text = content_tag(:span, label)
    icon = content_tag(:i, "", class: icon_class(conn, value, delimiter))

    content_tag(:a, [text, icon], href: path)
  end

  defp order_path(conn, value, delimiter) do
    updated_query_params = update_query_param(conn, value, delimiter)
    query_string = Plug.Conn.Query.encode(updated_query_params)

    "#{Map.get(conn, :request_path)}?#{query_string}"
  end

  defp update_query_param(conn, value, delimiter) do
    inverse = inverse_value(value)
    query_params = Map.get(conn, :query_params, %{})
    current_value = Map.get(query_params, "order", "")
    current_fields = String.split(current_value, delimiter)

    updated_fields =
      cond do
        Enum.member?(current_fields, value) -> replace_item(current_fields, value, inverse)
        Enum.member?(current_fields, inverse) -> replace_item(current_fields, inverse, value)
        true -> [value]
      end

    updated_value = Enum.join(updated_fields, delimiter)

    Map.put(query_params, "order", updated_value)
  end

  defp inverse_value(value), do: "-#{value}"

  defp replace_item(list, current, next) do
    case Enum.find_index(list, &(&1 == current)) do
      nil -> list
      index -> List.update_at(list, index, fn _ -> next end)
    end
  end

  defp icon_class(conn, value, delimiter) do
    base = "sort icon"
    query_params = Map.get(conn, :query_params, %{})
    current_value = Map.get(query_params, "order", "")
    current_fields = String.split(current_value, delimiter)

    cond do
      Enum.member?(current_fields, value) -> "#{base} ascending"
      Enum.member?(current_fields, inverse_value(value)) -> "#{base} descending"
      true -> base
    end
  end

  @doc """
  Render Data Table

  Example:

    <%=
      render_data_table(
        @conn,
        @customers,
        allowed_columns: allowed_columns(),
        default_columns: ["name", "slug", "actions"],
        selectable: true
      )
    %>

  Options:

    allowed_columns: map of allowed columns
    default_columns: list of strings
    selectable: include checkbox for bulk actions

  ## Features

  ### Column Ordering

  The `columns` query param can be used to define a custom order to table
  columns. For example, the default columns might be:

    Name | Slug | Actions

  By passing in the query param `?columns=status,name,address` the table
  will transform to show:

    Status | Name | Address

  This enables custom reporting in a standard and repeatable way across the
  application. Since query params are used to define the columns, any reports a
  user creates can be revisited using the same URL. Which in turn, also makes
  it easy to share with others.

  ### Table Export

  Custom exporters can be defined for any format, like `html`, `json`, `csv`,
  `xls`, or `pdf`. There's no conventions to learn or magic. As documented below,
  standard Elixir and Phoenix code can be used to define and write custom
  exporters in any format.

  ## Options

  The goal of the data table is to be extensible without introducing new
  data table specific conventions. Instead, enable extension using standard
  Elixir and Phoenix calls.

  ### Allowed Columns

  The value for `allowed_columns` should be a map. A complete example may look like:

    %{
      "name" => [
        label: fn (_conn) -> "Name" end,
        value: fn (_conn, row) -> row.name end,
      ],
      "slug" => [
        label: fn (_conn) -> "Slug" end,
        value: fn (_conn, row) -> row.slug end,
      ]
    }

  The key for each entry should be a URI friendly slug. It is used to match
  against the `columns` query param.

  The value for each entry is a keyword list. It must define a `label` and
  `value` function.

  The `label` function is used in column headings. It takes one argument, the
  `conn` struct. The most common return will be a simple bitstring, but
  the `conn` is included for more advanced usage, for instance creating an
  anchor link.

  The `value` function is used for the column value. It takes two arguments,
  the `conn` struct and the `row` value. The most common return will be calling
  an attribute on the row value, for instance `data.name`. The `conn` value is
  included for more advanced usage.

  #### Support for Different Content Types / Formats

  The required `label` and `value` functions should return simple values, like
  bitstrings, integers, and floats.

  Format specific values, such as HTML tags, should be defined in format
  specific keys. For instance:

      "name" => [
        label: fn (_conn) -> "Name" end,
        value: fn (_conn, row) -> row.name end,
        value_html: fn (conn, row) ->
          link(row.name, to: Routes.permission_path(conn, :show, row))
        end
      ]

  The data table function will first search for `label_<format>` and
  `value_<format>` keys. E.g. a standard `html` request would search for
  `label_html` and `value_html`. And in turn, a request for `csv` content type
  would search for `label_csv` and `value_csv`. If format specific keys are not
  found, the require `label` and `value` keys will be used as a fallback.

  ### Default Columns

  The default columns option should be a list of bitstrings, each corresponding
  to a key defined in the `allowed_columns` map.

    default_columns: ["name", "slug"]

  """
  def render_data_table(conn, data, options \\ []) do
    format = get_request_format(conn)
    columns = get_data_table_columns(conn, options)

    assigns = [
      columns: columns,
      conn: conn,
      data: data,
      id: Keyword.get(options, :id, Artemis.Helpers.UUID.call()),
      selectable: Keyword.get(options, :selectable),
      show_only: Keyword.get(options, :show_only)
    ]

    Phoenix.View.render(ArtemisWeb.LayoutView, "data_table.#{format}", assigns)
  end

  defp get_request_format(conn) do
    Phoenix.Controller.get_format(conn)
  rescue
    _ -> :html
  end

  @doc """
  Compares the `?columns=` query param value against the `allowed_columns`. If
  the query param is not set, compares the `default_columns` value instead.
  Returns a map of matching keys in `allowed_columns`.
  """
  def get_data_table_columns(conn, options) do
    selectable? = Keyword.get(options, :selectable, false)
    allowed_columns = Keyword.get(options, :allowed_columns, [])
    requested_columns = parse_data_table_requested_columns(conn, options)

    filtered =
      Enum.reduce(requested_columns, [], fn key, acc ->
        case Map.get(allowed_columns, key) do
          nil -> acc
          column -> [column | acc]
        end
      end)

    columns = Enum.reverse(filtered)

    case selectable? do
      true -> [get_checkbox_column() | columns]
      false -> columns
    end
  end

  defp get_checkbox_column() do
    [
      label: fn _conn -> nil end,
      label_html: fn _conn ->
        tag(:input, class: "ui checkbox select-all-rows", type: "checkbox", name: "id-toggle")
      end,
      value: fn _conn, _row -> nil end,
      value_html: fn _conn, row ->
        value = Map.get(row, :_id, Map.get(row, :id))

        tag(:input, class: "ui checkbox select-row", type: "checkbox", name: "id[]", value: value)
      end
    ]
  end

  @doc """
  Parse query params and return requested data table columns
  """
  def parse_data_table_requested_columns(conn, options \\ []) do
    conn
    |> Map.get(:query_params, %{})
    |> Map.get("columns")
    |> get_data_table_requested_columns(options)
  end

  defp get_data_table_requested_columns(nil, options), do: Keyword.get(options, :default_columns, [])
  defp get_data_table_requested_columns(value, _) when is_bitstring(value), do: String.split(value, ",")
  defp get_data_table_requested_columns(value, _) when is_list(value), do: value

  @doc """
  Renders the label for a data center column.
  """
  def render_data_table_label(conn, column, format) do
    key = String.to_atom("label_#{format}")
    default = Keyword.fetch!(column, :label)
    render = Keyword.get(column, key, default)

    render.(conn)
  end

  @doc """
  Renders the row value for a data center column.
  """
  def render_data_table_value(conn, column, row, format) do
    key = String.to_atom("value_#{format}")
    default = Keyword.fetch!(column, :value)
    render = Keyword.get(column, key, default)

    render.(conn, row)
  end

  @doc """
  Render a select box to allow users to choose custom columns
  """
  def render_data_table_column_selector(conn, available_columns) do
    selected = parse_data_table_requested_columns(conn)
    class = if length(selected) > 0, do: "active"

    sorted_by_selected =
      Enum.sort_by(available_columns, fn column ->
        key = elem(column, 1)
        index = Enum.find_index(selected, &(&1 == key)) || :infinity

        index
      end)

    assigns = [
      available: sorted_by_selected,
      class: class,
      conn: conn,
      selected: selected
    ]

    Phoenix.View.render(ArtemisWeb.LayoutView, "data_table_columns.html", assigns)
  end
end
