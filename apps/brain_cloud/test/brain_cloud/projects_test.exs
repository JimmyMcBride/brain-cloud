defmodule BrainCloud.ProjectsTest do
  use BrainCloud.DataCase, async: true

  alias BrainCloud.Projects

  @actor_id "00000000-0000-0000-0000-000000000001"

  test "creates a project with a trimmed name and actor provenance" do
    assert {:ok, project} = Projects.create_project(%{"name" => "  Research  "}, @actor_id)

    assert project.name == "Research"
    assert project.creator_actor_id == @actor_id
    assert project.id
    assert project.inserted_at
    assert Projects.get_project(project.id).id == project.id
  end

  test "validates project names and actor ids" do
    assert {:error, changeset} = Projects.create_project(%{"name" => "   "}, @actor_id)
    assert "can't be blank" in errors_on(changeset).name

    assert {:error, changeset} =
             Projects.create_project(%{"name" => String.duplicate("a", 121)}, @actor_id)

    assert "should be at most 120 character(s)" in errors_on(changeset).name

    assert {:error, changeset} = Projects.create_project(%{"name" => "Research"}, "invalid")
    assert "is invalid" in errors_on(changeset).creator_actor_id
  end
end
