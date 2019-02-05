package events

import (
	"encoding/hex"
	"encoding/json"
	"os"
	"testing"

	loom "github.com/loomnetwork/go-loom"
	"github.com/loomnetwork/go-loom/plugin/types"
	cdb "github.com/loomnetwork/loomchain/db"
	"github.com/loomnetwork/loomchain/store"
	"github.com/stretchr/testify/require"
)

var (
	valPubKeyHex1 = "3866f776276246e4f9998aa90632931d89b0d3a5930e804e02299533f55b39e1"
	valPubKeyHex2 = "7796b813617b283f81ea1747fbddbe73fe4b5fce0eac0728e47de51d8e506701"
)

func TestDBIndexerSendEvents(t *testing.T) {
	var tests = []struct {
		blockHeight uint64
		eventData   types.EventData
		err         error
	}{
		{
			blockHeight: 1,
			eventData: types.EventData{
				PluginName: "plugin1",
			},
		},
		{
			blockHeight: 2,
			eventData: types.EventData{
				PluginName: "plugin1",
			},
		},
	}

	mockEventStore := store.NewMockEventStore(store.NewMemStore())
	var dispatcher = &DBIndexerEventDispatcher{EventStore: mockEventStore}

	for _, test := range tests {
		msg, err := json.Marshal(test.eventData)
		require.Nil(t, err)
		err = dispatcher.Send(test.blockHeight, 0, msg)
		require.Equal(t, err, test.err)
	}
}

func TestDBIndexerGenUniqueContractID(t *testing.T) {
	pubKey1, _ := hex.DecodeString(valPubKeyHex1)
	pubKey2, _ := hex.DecodeString(valPubKeyHex2)

	var tests = []struct {
		blockHeight uint64
		eventData   types.EventData
		wantID      uint64
	}{
		{
			blockHeight: 1,
			eventData: types.EventData{
				PluginName: "plugin1",
			},
			wantID: 1,
		},
		{
			blockHeight: 2,
			eventData: types.EventData{
				PluginName: "plugin2",
			},
			wantID: 2,
		},
		{
			blockHeight: 3,
			eventData: types.EventData{
				PluginName: "plugin2",
			},
			wantID: 2,
		},
		{
			blockHeight: 4,
			eventData: types.EventData{
				PluginName: "plugin10",
			},
			wantID: 3,
		},
		{
			blockHeight: 5,
			eventData: types.EventData{
				PluginName: "plugin5",
			},
			wantID: 4,
		},
		{
			blockHeight: 6,
			eventData: types.EventData{
				PluginName: "",
				Address: loom.Address{
					ChainID: "default",
					Local:   loom.LocalAddressFromPublicKey(pubKey1),
				}.MarshalPB(),
			},
			wantID: 5,
		},
		{
			blockHeight: 7,
			eventData: types.EventData{
				PluginName: "",
				Address: loom.Address{
					ChainID: "default",
					Local:   loom.LocalAddressFromPublicKey(pubKey2),
				}.MarshalPB(),
			},
			wantID: 6,
		},
		{
			blockHeight: 8,
			eventData: types.EventData{
				PluginName: "",
				Address: loom.Address{
					ChainID: "default",
					Local:   loom.LocalAddressFromPublicKey(pubKey1),
				}.MarshalPB(),
			},
			wantID: 5,
		},
	}

	mockEventStore := store.NewMockEventStore(store.NewMemStore())
	var dispatcher = &DBIndexerEventDispatcher{EventStore: mockEventStore}

	for _, test := range tests {
		msg, err := json.Marshal(test.eventData)
		require.Nil(t, err)
		err = dispatcher.Send(test.blockHeight, 0, msg)
		require.Nil(t, err)
	}

	for _, test := range tests {
		var name = test.eventData.PluginName
		if test.eventData.PluginName == "" {
			name = loom.UnmarshalAddressPB(test.eventData.Address).String()
		}
		id := mockEventStore.GetContractID(name)
		require.Equal(t, test.wantID, id)
	}
}

func TestDBIndexerBatchWriting(t *testing.T) {
	var batch1 []*types.EventData
	var blockHeight1 = uint64(1)
	for i := 0; i < 10; i++ {
		batch1 = append(batch1, &types.EventData{
			PluginName:  "plugin1",
			BlockHeight: blockHeight1,
		})
	}

	var batch2 []*types.EventData
	var blockHeight2 = uint64(2)
	for i := 0; i < 10; i++ {
		batch2 = append(batch2, &types.EventData{
			PluginName:  "plugin2",
			BlockHeight: blockHeight2,
		})
	}

	var batch3 []*types.EventData
	var blockHeight3 = uint64(3)
	for i := 0; i < 10; i++ {
		batch2 = append(batch3, &types.EventData{
			PluginName:  "plugin3",
			BlockHeight: blockHeight3,
		})
	}

	dbpath := os.TempDir()
	db, err := cdb.LoadDB("goleveldb", "event", dbpath)
	if err != nil {
		t.Fatal(err)
	}
	defer os.RemoveAll(dbpath)

	var eventStore store.EventStore = store.NewKVEventStore(db)
	var dispatcher = &DBIndexerEventDispatcher{EventStore: eventStore}

	for i, event := range batch1 {
		emitMsg, err := json.Marshal(&event)
		require.Nil(t, err)
		err = dispatcher.Send(event.BlockHeight, i, emitMsg)
		require.Nil(t, err)
	}

	dispatcher.Flush()

	for i, event := range batch2 {
		emitMsg, err := json.Marshal(&event)
		require.Nil(t, err)
		err = dispatcher.Send(event.BlockHeight, i, emitMsg)
		require.Nil(t, err)
	}

	dispatcher.Flush()

	for i, event := range batch3 {
		emitMsg, err := json.Marshal(&event)
		require.Nil(t, err)
		err = dispatcher.Send(event.BlockHeight, i, emitMsg)
		require.Nil(t, err)
	}

	dispatcher.Flush()

	//check batch1 data
	eventsData, err := eventStore.FilterEvents(store.EventFilter{FromBlock: 1, ToBlock: 1})
	require.Nil(t, err)
	for _, event := range eventsData {
		require.Equal(t, event.PluginName, "plugin1")
		require.Equal(t, event.BlockHeight, uint64(1))
	}

	//check batch2 data
	eventsData, err = eventStore.FilterEvents(store.EventFilter{FromBlock: 2, ToBlock: 2})
	require.Nil(t, err)
	for _, event := range eventsData {
		require.Equal(t, event.PluginName, "plugin2")
		require.Equal(t, event.BlockHeight, uint64(2))
	}

	//check batch3 data
	eventsData, err = eventStore.FilterEvents(store.EventFilter{FromBlock: 3, ToBlock: 3})
	require.Nil(t, err)
	for _, event := range eventsData {
		require.Equal(t, event.PluginName, "plugin3")
		require.Equal(t, event.BlockHeight, uint64(3))
	}

}
