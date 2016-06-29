defmodule PhoenixApp.User do
  def fetch(user_id) do
    %{ body: body } = HTTPotion.get("https://randomuser.me/api?seed=#{user_id}")
    [result | _ ] = body |> Poison.decode! |> Map.get("results")
    result
  end
end
