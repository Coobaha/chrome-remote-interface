defmodule ChromeRemoteInterface.CodeGenerator do
  @moduledoc """
  Handles code generation for Chrome DevTools Protocol RPC modules.

  This module contains functions that generate type definitions and command functions
  for the CDP domains based on the protocol schema.
  """

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

        # Define command functions
        ChromeRemoteInterface.CodeGenerator.define_domain_commands(
          @domain["commands"] || [],
          domain_name
        )
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

        arg_doc =
          parameters
          |> List.wrap()
          |> Enum.map(fn param ->
            "#{param["name"]} - <#{param["$ref"] || param["type"]}> - #{param["description"]}"
          end)
          |> Enum.join("\n")

        return_doc =
          return_vals
          |> List.wrap()
          |> Enum.map(fn ret ->
            "#{ret["name"]} - <#{ret["$ref"] || ret["type"]}> - #{ret["description"]}"
          end)
          |> Enum.join("\n")

        @doc """
        #{description}

        Parameters:
        #{arg_doc}

        Returns:
        #{if Enum.empty?(return_vals), do: "nil", else: return_doc}
        """

        def unquote(:"#{name}")(page_pid) do
          page_pid
          |> PageSession.execute_command(
            unquote("#{domain_name}.#{name}"),
            %{},
            []
          )
        end

        def unquote(:"#{name}")(page_pid, parameters) do
          page_pid
          |> PageSession.execute_command(
            unquote("#{domain_name}.#{name}"),
            parameters,
            []
          )
        end

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
