defmodule ChromeRemoteInterface do
  @moduledoc """
  Documentation for ChromeRemoteInterface.

  This is the main entry point for interacting with the Chrome DevTools Protocol.
  It provides functions for connecting to Chrome, opening pages, and executing
  commands against Chrome's various domains.

  The module also handles generating code for Chrome DevTools Protocol commands
  based on the protocol specification. 
  """

  alias ChromeRemoteInterface.CodeGenerator

  require ChromeRemoteInterface.CodeGenerator

  @protocol_env_key "CRI_PROTOCOL_VERSION"
  @protocol_versions ["1-2", "1-3", "tot"]
  @protocol_version (if (vsn = System.get_env(@protocol_env_key)) in @protocol_versions do
                       vsn
                     else
                       "tot"
                     end)
  IO.puts(
    "Compiling ChromeRemoteInterface with Chrome DevTools Protocol version: '#{@protocol_version}'"
  )

  @doc """
  Gets the current version of the Chrome Debugger Protocol
  """
  def protocol_version() do
    @protocol_version
  end

  protocol =
    File.read!("priv/#{@protocol_version}/protocol.json")
    |> Jason.decode!()

  # Generate ChromeRemoteInterface.RPC Modules for each domain
  Enum.each(protocol["domains"], fn domain ->
    CodeGenerator.generate_domain_module(domain)
  end)
end
