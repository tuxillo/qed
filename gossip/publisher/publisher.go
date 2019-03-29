/*
   Copyright 2018-2019 Banco Bilbao Vizcaya Argentaria, S.A.

   Licensed under the Apache License, Version 2.0 (the "License");
   you may not use this file except in compliance with the License.
   You may obtain a copy of the License at

       http://www.apache.org/licenses/LICENSE-2.0

   Unless required by applicable law or agreed to in writing, software
   distributed under the License is distributed on an "AS IS" BASIS,
   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
   See the License for the specific language governing permissions and
   limitations under the License.
*/

package publisher

import (
	"context"

	"github.com/bbva/qed/gossip"
	"github.com/bbva/qed/protocol"
	"github.com/coocood/freecache"

	"github.com/prometheus/client_golang/prometheus"
)

var (
	QedPublisherInstancesCount = prometheus.NewGauge(
		prometheus.GaugeOpts{
			Name: "qed_publisher_instances_count",
			Help: "Number of publisher agents running.",
		},
	)

	QedPublisherBatchesReceivedTotal = prometheus.NewCounter(
		prometheus.CounterOpts{
			Name: "qed_publisher_batches_received_total",
			Help: "Number of batches received by publishers.",
		},
	)

	QedPublisherBatchesProcessSeconds = prometheus.NewSummary(
		prometheus.SummaryOpts{
			Name: "qed_publisher_batches_process_seconds",
			Help: "Duration of Publisher batch processing",
		},
	)
)

type Publisher struct {
	processed *freecache.Cache
}

func (p Publisher) Metrics() []prometheus.Collector {
	return []prometheus.Collector{
		QedPublisherInstancesCount,
		QedPublisherBatchesReceivedTotal,
		QedPublisherBatchesProcessSeconds,
	}
}

func (p *Publisher) Process(a *gossip.Agent, ctx context.Context) error {
	QedPublisherBatchesReceivedTotal.Inc()

	store := a.SnapshotStore()
	b := ctx.Value("batch").(*protocol.BatchSnapshots)

	a.Task(func() error {
		timer := prometheus.NewTimer(QedPublisherBatchesProcessSeconds)
		defer timer.ObserveDuration()

		var batch protocol.BatchSnapshots

		for _, signedSnap := range b.Snapshots {
			_, err := p.processed.Get(signedSnap.Signature)
			if err != nil {
				p.processed.Set(signedSnap.Signature, []byte{0x0}, 0)
				batch.Snapshots = append(batch.Snapshots, signedSnap)
			}
		}
		if len(batch.Snapshots) < 1 {
			return nil
		}

		batch.From = b.From
		batch.TTL = b.TTL

		return store.PutBatch(&batch)
	})
}

