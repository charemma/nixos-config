# ocr-batch.nix -- adds a text layer to scanned PDFs in the Syncthing scanner inbox.
#
# simple-scan OCRs fresh scans on the fly via ocr-script (desktop.nix). PDFs that
# arrive from other devices, phone scans or older batches have no text layer.
# This timer walks the scanner inbox and OCRs every PDF without fonts in place.
#
# Enable it on exactly one host. Syncthing replicates the result to the others,
# and two hosts OCRing the same file would produce sync conflicts.
#
# Manual use: `ocr-batch --dry-run` lists what would be processed, `ocr-batch`
# processes it. OCR_BATCH_DIR and OCR_BATCH_LANGS override the defaults.
{ config, lib, pkgs, ... }:

let
  cfg = config.services.ocr-batch;

  ocrBatch = pkgs.writeShellApplication {
    name = "ocr-batch";
    runtimeInputs = with pkgs; [ ocrmypdf poppler-utils findutils coreutils util-linux ];
    text = ''
      dir="''${OCR_BATCH_DIR:-$HOME/Sync/Scanner}"
      langs="''${OCR_BATCH_LANGS:-deu+eng+ell}"
      # Skip files touched recently: they may still be written by the scanner
      # or in the middle of a Syncthing transfer.
      min_age_minutes="''${OCR_BATCH_MIN_AGE_MINUTES:-5}"
      dry_run=false
      [[ "''${1:-}" == "--dry-run" ]] && dry_run=true

      # One run at a time, even if the timer fires while a long batch is active.
      exec 9>"/tmp/ocr-batch.lock"
      if ! flock -n 9; then
        echo "ocr-batch: another run is active, exiting"
        exit 0
      fi

      # pdffonts prints a two line header followed by one line per font.
      # A scan without a text layer has no fonts at all.
      has_text_layer() {
        [[ "$(pdffonts "$1" 2>/dev/null | tail -n +3 | wc -l)" -gt 0 ]]
      }

      processed=0
      skipped=0
      failed=0

      # Top level and one folder below (e.g. unbatched/), never tmp/ and never
      # Syncthing conflict copies. The user resolves those by hand.
      while IFS= read -r -d "" pdf; do
        if ! pdffonts "$pdf" >/dev/null 2>&1; then
          echo "SKIP  (unreadable or encrypted) $pdf"
          skipped=$((skipped + 1))
          continue
        fi
        if has_text_layer "$pdf"; then
          continue
        fi
        if $dry_run; then
          echo "WOULD $pdf"
          processed=$((processed + 1))
          continue
        fi

        # Syncthing always ignores its own temp pattern ".syncthing.<name>.tmp",
        # so the half-written output never gets replicated. The final mv is
        # atomic on the same filesystem, other devices only ever see a finished PDF.
        tmp="$(dirname "$pdf")/.syncthing.$(basename "$pdf").tmp"
        if ocrmypdf --skip-text --deskew --clean --rotate-pages -l "$langs" "$pdf" "$tmp"; then
          mv -f "$tmp" "$pdf"
          echo "OK    $pdf"
          processed=$((processed + 1))
        else
          rm -f "$tmp"
          echo "FAIL  $pdf"
          failed=$((failed + 1))
        fi
      done < <(find "$dir" -maxdepth 2 -type f -iname '*.pdf' \
                 -not -name '.sync-conflict-*' \
                 -not -name '.syncthing.*' \
                 -not -path "$dir/tmp/*" \
                 -mmin +"$min_age_minutes" -print0 | sort -z)

      echo "ocr-batch: processed=$processed skipped=$skipped failed=$failed dry_run=$dry_run"
      [[ "$failed" -eq 0 ]]
    '';
  };
in {
  options.services.ocr-batch = {
    enable = lib.mkEnableOption "periodic OCR of scanned PDFs in the Syncthing scanner inbox";

    user = lib.mkOption {
      type = lib.types.str;
      default = "charemma";
      description = "User that owns the scanner inbox. The service runs as this user.";
    };

    directory = lib.mkOption {
      type = lib.types.str;
      default = "/home/charemma/Sync/Scanner";
      description = "Folder to scan for PDFs without a text layer.";
    };

    languages = lib.mkOption {
      type = lib.types.str;
      default = "deu+eng+ell";
      description = "Tesseract language string passed to ocrmypdf -l.";
    };

    onCalendar = lib.mkOption {
      type = lib.types.str;
      default = "hourly";
      description = "systemd OnCalendar expression for the timer.";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ ocrBatch ];

    systemd.services.ocr-batch = {
      description = "OCR scanned PDFs without a text layer in ${cfg.directory}";
      environment = {
        OCR_BATCH_DIR = cfg.directory;
        OCR_BATCH_LANGS = cfg.languages;
      };
      serviceConfig = {
        Type = "oneshot";
        User = cfg.user;
        ExecStart = "${ocrBatch}/bin/ocr-batch";
        # Background job, must not compete with the interactive session.
        Nice = 10;
        IOSchedulingClass = "idle";
      };
    };

    systemd.timers.ocr-batch = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = cfg.onCalendar;
        Persistent = true;
        RandomizedDelaySec = "5m";
      };
    };
  };
}
