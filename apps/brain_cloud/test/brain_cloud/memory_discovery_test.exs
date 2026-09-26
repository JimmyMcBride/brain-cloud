defmodule BrainCloud.MemoryDiscoveryTest do
  use BrainCloud.DataCase, async: true

  alias BrainCloud.Memories
  alias BrainCloud.Memories.Memory
  alias BrainCloud.Memories.MemoryRevision
  alias BrainCloud.Projects
  alias BrainCloud.Repo

  setup do
    owner = identity_fixture()
    {:ok, project} = Projects.create_project(%{name: "Discovery"}, owner.auth_context)
    %{owner: owner, project: project}
  end

  test "selects one latest revision without widening the revision write boundary", %{
    owner: owner,
    project: project
  } do
    {:ok, memory} = create_memory(project.id, "Revision one", "First body", owner)
    first_revision = List.first(memory.revisions)
    second_content = "# Revision two\nLatest body"

    invalid_changeset =
      MemoryRevision.changeset(%MemoryRevision{}, %{
        memory_id: memory.id,
        revision_number: 2,
        title: "Revision two",
        content: second_content,
        content_type: "text/markdown",
        actor_user_id: owner.user.id
      })

    refute invalid_changeset.valid?
    assert "must be equal to 1" in errors_on(invalid_changeset).revision_number

    second_revision =
      %MemoryRevision{}
      |> change(%{
        memory_id: memory.id,
        revision_number: 2,
        title: "Revision two",
        content: second_content,
        content_type: "text/markdown",
        content_hash: Base.encode16(:crypto.hash(:sha256, second_content), case: :lower),
        actor_user_id: owner.user.id
      })
      |> Repo.insert!()

    assert {[%{memory: listed, revision: revision, excerpt: excerpt}], false} =
             Memories.list_memories(project, 20)

    assert listed.id == memory.id
    assert revision.id == second_revision.id
    assert revision.revision_number == 2
    assert revision.id != first_revision.id
    assert excerpt == "Revision two Latest body"
  end

  test "paginates equal timestamps and survives a deleted anchor", %{
    owner: owner,
    project: project
  } do
    memories =
      for title <- ["One", "Two", "Three"] do
        {:ok, memory} = create_memory(project.id, title, title, owner)
        memory
      end

    inserted_at = ~U[2026-09-26 01:02:03.123456Z]
    ids = Enum.map(memories, & &1.id)

    from(memory in Memory, where: memory.id in ^ids)
    |> Repo.update_all(set: [inserted_at: inserted_at])

    {[%{memory: first}], true} = Memories.list_memories(project, 1)
    Repo.delete!(first)

    {remaining, false} =
      Memories.list_memories(project, 100, {inserted_at, first.id})

    assert Enum.map(remaining, & &1.memory.id) ==
             ids |> Enum.reject(&(&1 == first.id)) |> Enum.sort()
  end

  defp create_memory(project_id, title, content, owner) do
    Memories.create_memory(
      project_id,
      %{title: title, content: content, content_type: "text/markdown"},
      owner.auth_context
    )
  end
end
