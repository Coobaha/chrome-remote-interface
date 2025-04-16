defmodule ChromeRemoteInterface.CodeGenerator do
  @moduledoc """
  Handles code generation for Chrome DevTools Protocol RPC modules.

  This module contains functions that generate type definitions and command functions
  for the CDP domains based on the protocol schema.
  """

  alias ChromeRemoteInterface.TypeHelper
  alias ChromeRemoteInterface.PageSession

  @doc """
  Generate a module for a CDP domain.

  ## Parameters

  - `domain`: The domain definition from the CDP protocol schema
  """
  defmacro generate_domain_module(domain) do
    quote bind_quoted: [domain: domain] do
      domain_name = domain["domain"]

      defmodule Module.concat(ChromeRemoteInterface.RPC, domain_name) do
        @domain domain
        @moduledoc domain["description"]

        @spec experimental?() :: boolean()
        def experimental?(), do: unquote(domain["experimental"] || false)

        # Register type attribute before defining types
        if domain_types = @domain["types"] do
          ChromeRemoteInterface.CodeGenerator.define_domain_types(
            domain_types,
            domain_name
          )
        end

        # Define command functions
        ChromeRemoteInterface.CodeGenerator.define_domain_commands(
          @domain["commands"] || [],
          domain_name
        )
      end
    end
  end

  @doc """
  Define type specifications for a domain.

  ## Parameters

  - `types`: The list of type definitions from the CDP domain
  - `domain_name`: The name of the domain
  """
  defmacro define_domain_types(types, domain_name) do
    quote bind_quoted: [types: types, domain_name: domain_name] do
      Module.register_attribute(__MODULE__, :typedoc, accumulate: false, persist: true)

      # Define each type in the domain
      for type <- types do
        type_id = type["id"]
        type_name = String.to_atom(TypeHelper.format_type_name(type_id))
        type_description = TypeHelper.format_description(type["description"])
        type_experimental = Map.get(type, "experimental", false)

        # Generate typedoc comment
        typedoc =
          if type_experimental do
            "#{type_description}\n\n**Experimental**: This type is experimental."
          else
            type_description
          end

        @typedoc typedoc

        # Define the appropriate type based on the CDP type
        cond do
          type["type"] == "string" && Map.has_key?(type, "enum") ->
            # For enum types, use a fixed String.t() type
            @type unquote(type_name)() :: String.t()

          type["type"] == "object" && Map.has_key?(type, "properties") ->
            # Object with properties - define with detailed map spec
            properties = type["properties"] || []
            map_type_spec = TypeHelper.generate_map_type_spec(properties, domain_name)
            @type unquote(type_name)() :: unquote(Code.string_to_quoted!(map_type_spec))

          type["type"] == "string" ->
            # Simple string type
            @type unquote(type_name)() :: String.t()

          true ->
            # Default to any for other types
            @type unquote(type_name)() :: any()
        end
      end
    end
  end

  @doc """
  Define command functions for a domain.

  ## Parameters

  - `commands`: The list of commands from the CDP domain
  - `domain_name`: The name of the domain
  """
  defmacro define_domain_commands(commands, domain_name) do
    quote bind_quoted: [commands: commands, domain_name: domain_name] do
      for command <- commands do
        name = command["name"]
        description = command["description"]

        parameters = command["parameters"] || []
        return_vals = command["returns"] || []

        # Create return type specs
        return_type =
          if Enum.empty?(return_vals) do
            "{:ok, nil} | {:error, any()}"
          else
            return_fields =
              return_vals
              |> Enum.map(fn ret ->
                ret_name = ret["name"]
                ret_type = TypeHelper.param_type_spec(ret, domain_name)
                "#{ret_name}: #{ret_type}"
              end)
              |> Enum.join(", ")

            "{:ok, %{#{return_fields}}} | {:error, any()}"
          end

        arg_doc =
          parameters
          |> List.wrap()
          |> Enum.map(fn param ->
            "#{param["name"]} - <#{param["$ref"] || param["type"]}> - #{param["description"]}"
          end)

        @doc """
        #{description}

        Parameters:
        #{arg_doc}
        """
        @spec unquote(:"#{name}")(pid()) :: unquote(Code.string_to_quoted!(return_type))
        def unquote(:"#{name}")(page_pid) do
          page_pid
          |> PageSession.execute_command(
            unquote("#{domain_name}.#{name}"),
            %{},
            []
          )
        end

        # For the commands with parameters, we'll use a more generic map type
        # rather than trying to enforce specific parameter types in the typespec
        @spec unquote(:"#{name}")(pid(), map()) :: unquote(Code.string_to_quoted!(return_type))
        def unquote(:"#{name}")(page_pid, parameters) do
          page_pid
          |> PageSession.execute_command(
            unquote("#{domain_name}.#{name}"),
            parameters,
            []
          )
        end

        @spec unquote(:"#{name}")(pid(), map(), keyword()) ::
                unquote(Code.string_to_quoted!(return_type))
        def unquote(:"#{name}")(page_pid, parameters, opts) when is_list(opts) do
          page_pid
          |> PageSession.execute_command(
            unquote("#{domain_name}.#{name}"),
            parameters,
            opts
          )
        end
      end
    end
  end
end
