defmodule Artemis.DeleteDataCenterTest do
  use Artemis.DataCase

  import Artemis.Factories

  alias Artemis.DataCenter
  alias Artemis.DeleteDataCenter

  describe "call!" do
    test "raises an exception when id not found" do
      invalid_id = 50_000_000

      assert_raise Artemis.Context.Error, fn ->
        DeleteDataCenter.call!(invalid_id, Mock.system_user())
      end
    end

    test "deletes a record when passed valid params" do
      record = insert(:data_center)

      %DataCenter{} = DeleteDataCenter.call!(record, Mock.system_user())

      assert Repo.get(DataCenter, record.id) == nil
    end

    test "deletes a record when passed an id and valid params" do
      record = insert(:data_center)

      %DataCenter{} = DeleteDataCenter.call!(record.id, Mock.system_user())

      assert Repo.get(DataCenter, record.id) == nil
    end
  end

  describe "call" do
    test "returns an error when record not found" do
      invalid_id = 50_000_000

      {:error, _} = DeleteDataCenter.call(invalid_id, Mock.system_user())
    end

    test "deletes a record when passed valid params" do
      record = insert(:data_center)

      {:ok, _} = DeleteDataCenter.call(record, Mock.system_user())

      assert Repo.get(DataCenter, record.id) == nil
    end
  end

  describe "broadcasts" do
    test "publishes event and record" do
      ArtemisPubSub.subscribe(Artemis.Event.get_broadcast_topic())

      {:ok, data_center} = DeleteDataCenter.call(insert(:data_center), Mock.system_user())

      assert_received %Phoenix.Socket.Broadcast{
        event: "data-center:deleted",
        payload: %{
          data: ^data_center
        }
      }
    end
  end
end
