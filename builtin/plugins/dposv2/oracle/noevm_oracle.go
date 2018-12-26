// +build !evm

package oracle

import "errors"

type Config struct {
	Enabled bool
}

type TimeLockWorkerConfig struct {
	cfg *Config
}

type Oracle struct {
}

func (o *Oracle) Init(chainID string) error {
	return errors.New("not implemented in non-EVM build")
}

func NewOracle(cfg *Config) *Oracle {
	return nil
}

func (o *Oracle) Run() {

}
