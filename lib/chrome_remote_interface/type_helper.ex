defmodule ChromeRemoteInterface.TypeHelper do
  @moduledoc """
  Helper module for converting Chrome DevTools Protocol (CDP) types to Elixir type specs.

  This module is used internally by the code generation process to create
  proper typespecs for the RPC functions based on the CDP protocol schema.
  """

  @doc """
  Convert a CDP primitive type to an Elixir type spec string.

  ## Examples

      iex> ChromeRemoteInterface.TypeHelper.cdp_type_to_spec("boolean")
      "boolean()"

      iex> ChromeRemoteInterface.TypeHelper.cdp_type_to_spec("string")
      "String.t()"
  """
  def cdp_type_to_spec("boolean"), do: "boolean()"
  def cdp_type_to_spec("integer"), do: "integer()"
  def cdp_type_to_spec("number"), do: "float()"
  def cdp_type_to_spec("string"), do: "String.t()"
  def cdp_type_to_spec("object"), do: "map()"
  def cdp_type_to_spec("array"), do: "list()"
  def cdp_type_to_spec("any"), do: "any()"
  def cdp_type_to_spec(_), do: "any()"

  @doc """
  Convert a CDP reference type to an Elixir type spec string.

  Handles references in the format "Domain.Type".

  ## Examples

      iex> ChromeRemoteInterface.TypeHelper.cdp_ref_to_spec("Page.FrameId", "Page")
      "String.t()"

      iex> ChromeRemoteInterface.TypeHelper.cdp_ref_to_spec("FrameId", "Page")
      "String.t()"
  """
  def cdp_ref_to_spec(ref, _current_domain) do
    # Handle cross-domain references (Domain.Type) and same-domain references (Type)
    case String.split(ref, ".") do
      [domain, type] ->
        # Cross-domain reference
        "ChromeRemoteInterface.RPC.#{domain}.#{format_type_name(type)}()"
      [type] ->
        # Same-domain reference
        "#{format_type_name(type)}()"
    end
  end

  @doc """
  Format a type name according to Elixir conventions.
  Converts CamelCase to snake_case for most types.
  Adds cdp_ prefix for reserved names.
  """
  def format_type_name(name) do
    # Convert to snake_case, handling special cases
    snake_case =
      if String.ends_with?(name, "ID") do
        String.replace(name, ~r/ID$/, "_id")
        |> Macro.underscore()
        |> String.replace("_id", "_id")
      else
        Macro.underscore(name)
      end

    "cdp_#{snake_case}"
  end

  @doc """
  Extract the type spec from a CDP parameter description.

  Handles complex nested types including references and arrays.

  ## Parameters

  - `param`: A map containing the CDP parameter description
  - `domain`: The current CDP domain name
  """
  def param_type_spec(param, domain) do
    cond do
      Map.has_key?(param, "$ref") ->
        cdp_ref_to_spec(param["$ref"], domain)

      Map.has_key?(param, "type") ->
        if param["type"] == "array" && Map.has_key?(param, "items") do
          items = param["items"]

          if Map.has_key?(items, "$ref") do
            # Reference type in items
            "list(#{cdp_ref_to_spec(items["$ref"], domain)})"
          else
            "list(#{cdp_type_to_spec(items["type"])})"
          end
        else
          cdp_type_to_spec(param["type"])
        end

      true ->
        "any()"
    end
  end

  @doc """
  Format a description string for use in a module doc
  """
  def format_description(nil), do: nil

  def format_description(description) do
    # Ensure there's a newline after the opening heredoc
    "\n#{description}\n"
  end

  @doc """
  Generate a map type spec with property information for an object type.

  Returns a string representation of the type spec that includes all properties.

  ## Parameters

  - `properties`: The properties list from the CDP type definition
  - `domain_name`: The current domain name for resolving references
  """
  def generate_map_type_spec(properties, domain_name) do
    fields =
      properties
      |> Enum.map(fn prop ->
        field_name = Macro.underscore(prop["name"])
        field_type = param_type_spec(prop, domain_name)
        required = not Map.get(prop, "optional", false)

        if required do
          "#{field_name}: #{field_type}"
        else
          "#{field_name}: #{field_type} | nil"
        end
      end)
      |> Enum.join(", ")

    "%{#{fields}}"
  end
end
