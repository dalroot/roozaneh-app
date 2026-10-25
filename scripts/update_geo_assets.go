package main

import (
	"bytes"
	"encoding/binary"
	"fmt"
	"io"
	"net/http"
	"os"
	"path/filepath"
	"time"

	bolt "go.etcd.io/bbolt"
)

func encodeSavedBinary(content []byte, lastUpdated time.Time, etag string) []byte {
	var buf bytes.Buffer
	buf.WriteByte(1) // version = 1

	var lenBuf [10]byte
	n := binary.PutUvarint(lenBuf[:], uint64(len(content)))
	buf.Write(lenBuf[:n])
	buf.Write(content)

	var timeBuf [8]byte
	binary.BigEndian.PutUint64(timeBuf[:], uint64(lastUpdated.Unix()))
	buf.Write(timeBuf[:])

	n = binary.PutUvarint(lenBuf[:], uint64(len(etag)))
	buf.Write(lenBuf[:n])
	buf.WriteString(etag)

	return buf.Bytes()
}

func downloadFileIfNeeded(url, destPath string) ([]byte, error) {
	if _, err := os.Stat(destPath); err == nil {
		fmt.Printf("Using existing file: %s\n", destPath)
		return os.ReadFile(destPath)
	}

	fmt.Printf("Downloading %s to %s...\n", url, destPath)
	client := &http.Client{Timeout: 30 * time.Second}
	resp, err := client.Get(url)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("bad status: %s", resp.Status)
	}

	data, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, err
	}

	if err := os.WriteFile(destPath, data, 0644); err != nil {
		return nil, err
	}
	return data, nil
}

func main() {
	// Find project root
	dir, err := os.Getwd()
	if err != nil {
		panic(err)
	}
	var rootDir string
	if _, err := os.Stat(filepath.Join(dir, "pubspec.yaml")); err == nil {
		rootDir = dir
	} else if _, err := os.Stat(filepath.Join(dir, "..", "pubspec.yaml")); err == nil {
		rootDir = filepath.Join(dir, "..")
	} else {
		rootDir = dir
	}

	assetsDir := filepath.Join(rootDir, "assets", "core")
	_ = os.MkdirAll(assetsDir, 0755)

	geoIPPath := filepath.Join(assetsDir, "geoip-ir.srs")
	geoSitePath := filepath.Join(assetsDir, "geosite-ir.srs")
	clashDBPath := filepath.Join(assetsDir, "clash.db")

	geoIP, err := downloadFileIfNeeded("https://raw.githubusercontent.com/hiddify/hiddify-geo/rule-set/country/geoip-ir.srs", geoIPPath)
	if err != nil {
		panic(err)
	}
	geoSite, err := downloadFileIfNeeded("https://raw.githubusercontent.com/hiddify/hiddify-geo/rule-set/country/geosite-ir.srs", geoSitePath)
	if err != nil {
		panic(err)
	}

	_ = os.Remove(clashDBPath)
	db, err := bolt.Open(clashDBPath, 0644, nil)
	if err != nil {
		panic(err)
	}
	defer db.Close()

	now := time.Now()
	valIP := encodeSavedBinary(geoIP, now, "v1")
	valSite := encodeSavedBinary(geoSite, now, "v1")

	err = db.Update(func(tx *bolt.Tx) error {
		b, err := tx.CreateBucketIfNotExists([]byte("rule_set"))
		if err != nil {
			return err
		}
		if err := b.Put([]byte("geoip-ir"), valIP); err != nil {
			return err
		}
		if err := b.Put([]byte("geosite-ir"), valSite); err != nil {
			return err
		}
		return nil
	})
	if err != nil {
		panic(err)
	}

	fmt.Printf("Successfully generated %s with geoip-ir (%d bytes) and geosite-ir (%d bytes)!\n", clashDBPath, len(geoIP), len(geoSite))
}
