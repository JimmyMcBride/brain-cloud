defmodule BrainCloudWeb.MemoryCursorTest do
  use ExUnit.Case, async: true

  alias BrainCloudWeb.MemoryCursor

  test "round-trips the exact v1 memory position" do
    memory = %{
      id: "123e4567-e89b-12d3-a456-426614174000",
      inserted_at: ~U[2026-09-26 12:34:56.123456Z]
    }

    encoded = MemoryCursor.encode(%{memory: memory})

    assert {:ok, {memory.inserted_at, memory.id}} == MemoryCursor.decode(encoded)
    refute String.contains?(encoded, "=")
  end

  test "rejects malformed, noncanonical, nested, and oversized values" do
    invalid_payloads = [
      %{"v" => 2, "inserted_at" => "2026-09-26T12:34:56.123456Z", "id" => Ecto.UUID.generate()},
      %{"v" => 1, "inserted_at" => "2026-09-26T12:34:56Z", "id" => Ecto.UUID.generate()},
      %{"v" => 1, "inserted_at" => "2026-09-26T12:34:56.123456Z", "id" => "BAD"},
      %{
        "v" => 1,
        "inserted_at" => "2026-09-26T12:34:56.123456Z",
        "id" => Ecto.UUID.generate(),
        "extra" => true
      }
    ]

    for payload <- invalid_payloads do
      encoded = payload |> Jason.encode!() |> Base.url_encode64(padding: false)
      assert {:error, :invalid_cursor} = MemoryCursor.decode(encoded)
    end

    assert {:error, :invalid_cursor} = MemoryCursor.decode("")
    assert {:error, :invalid_cursor} = MemoryCursor.decode(%{})
    assert {:error, :invalid_cursor} = MemoryCursor.decode("e30=")
    assert {:error, :invalid_cursor} = MemoryCursor.decode(String.duplicate("a", 513))
  end
end
