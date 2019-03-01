// +build evm

package auth

import (
	"github.com/loomnetwork/go-loom/common/evmcompat"
	"github.com/pkg/errors"
)

func verifySolidity(tx SignedTx) ([]byte, error) {
	ethAddr, err := evmcompat.SolidityRecover(tx.PublicKey, tx.Signature)
	if err != nil {
		return nil, errors.Wrap(err, "verify solidity key")
	}
	return ethAddr.Bytes(), nil
}
