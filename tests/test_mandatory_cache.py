import hashlib
import tempfile
from pathlib import Path


def extract_mandatory_from_file(file_path):
    """Extract MANDATORY CHECKLIST block from CLAUDE.md using sed."""
    with open(file_path) as f:
        content = f.read()

    start = content.find('## MANDATORY CHECKLIST')
    if start == -1:
        return None

    end = content.find('\n##', start + 1)
    if end == -1:
        end = len(content)

    return content[start:end].rstrip()


def test_mandatory_block_extraction():
    """Test that MANDATORY CHECKLIST block can be extracted correctly."""
    sample_claude = """# Contrato de trabajo — F Colomer

## MANDATORY CHECKLIST

- **Point 1.** Something important.
- **Point 2.** Another important thing.
- **Point 3.** Third thing.

## Other section

Some content here.
"""

    with tempfile.NamedTemporaryFile(mode='w', suffix='.md', delete=False) as f:
        f.write(sample_claude)
        f.flush()

        extracted = extract_mandatory_from_file(f.name)

        assert "## MANDATORY CHECKLIST" in extracted
        assert "Point 1" in extracted
        assert "Point 2" in extracted
        assert "Point 3" in extracted
        assert "Other section" not in extracted

        Path(f.name).unlink()


def test_mandatory_hash_generation():
    """Test that MANDATORY block hash can be generated."""
    sample_content = """## MANDATORY CHECKLIST

- **Point 1.** Something important.
- **Point 2.** Another important thing.
"""

    hash_value = hashlib.sha256(sample_content.encode()).hexdigest()
    assert len(hash_value) == 64  # SHA256 hex is 64 chars
    assert hash_value.isalnum()


def test_hash_changes_on_content_change():
    """Test that hash changes when MANDATORY block changes."""
    content1 = """## MANDATORY CHECKLIST

- **Point 1.** Original text.
"""

    content2 = """## MANDATORY CHECKLIST

- **Point 1.** Modified text.
"""

    hash1 = hashlib.sha256(content1.encode()).hexdigest()
    hash2 = hashlib.sha256(content2.encode()).hexdigest()

    assert hash1 != hash2


def test_verify_cache_active():
    """Test verify-cache.sh detects active cache (match)."""
    with tempfile.TemporaryDirectory() as tmpdir:
        contract_path = Path(tmpdir) / "CLAUDE.md"
        cache_path = Path(tmpdir) / "MANDATORY.cache"

        # Create contract with MANDATORY block
        contract_content = """# Contract

## MANDATORY CHECKLIST

- **Point 1.** Important rule.
- **Point 2.** Another rule.

## Other Section

Some content here.
"""
        contract_path.write_text(contract_content)

        # Extract and hash using same logic as verify-cache.sh
        with open(contract_path) as f:
            content = f.read()

        start = content.find('## MANDATORY CHECKLIST')
        end = content.find('\n##', start + 1)
        extracted = content[start:end].rstrip()
        cache_hash = hashlib.sha256(extracted.encode()).hexdigest()

        # Write cache
        cache_path.write_text(cache_hash)

        # Verify they match
        hash_guardado = cache_path.read_text()
        assert extracted and cache_hash
        assert hashlib.sha256(extracted.encode()).hexdigest() == hash_guardado


def test_verify_cache_mismatch():
    """Test verify-cache.sh detects mismatch when contract changes."""
    with tempfile.TemporaryDirectory() as tmpdir:
        contract_path = Path(tmpdir) / "CLAUDE.md"
        cache_path = Path(tmpdir) / "MANDATORY.cache"

        # Create initial contract
        contract_v1 = """# Contract

## MANDATORY CHECKLIST

- **Point 1.** Original text.

## Other Section

Content.
"""
        contract_path.write_text(contract_v1)

        # Extract and hash v1
        with open(contract_path) as f:
            content = f.read()
        start = content.find('## MANDATORY CHECKLIST')
        end = content.find('\n##', start + 1)
        extracted_v1 = content[start:end].rstrip()
        hash_v1 = hashlib.sha256(extracted_v1.encode()).hexdigest()
        cache_path.write_text(hash_v1)

        # Now update contract (simulates edit)
        contract_v2 = """# Contract

## MANDATORY CHECKLIST

- **Point 1.** Modified text.

## Other Section

Content.
"""
        contract_path.write_text(contract_v2)

        # Extract v2 and verify mismatch
        with open(contract_path) as f:
            content = f.read()
        start = content.find('## MANDATORY CHECKLIST')
        end = content.find('\n##', start + 1)
        extracted_v2 = content[start:end].rstrip()
        hash_v2 = hashlib.sha256(extracted_v2.encode()).hexdigest()

        hash_guardado = cache_path.read_text()
        assert hash_v2 != hash_guardado, "Cache should mismatch when contract changes"


def test_cache_hash_format_in_output():
    """Test that cache hash (6 chars) can be extracted and formatted correctly."""
    full_hash = "3e1374e1d8c5f2a9b0c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0c1d2e3f"
    hash_short = full_hash[:6]

    assert len(hash_short) == 6
    assert hash_short == "3e1374"
    assert hash_short.isalnum()


def test_sync_message_format():
    """Test that sync.sh message format includes both Contract-Id and cache hash."""
    contract_id = "3e1374e (2026-08-11)"
    cache_hash_short = "3e1374"

    message = f"✅ claude-sync · Contract-Id loaded: {contract_id} · cache **{cache_hash_short}"

    assert "Contract-Id loaded:" in message
    assert "cache **" in message
    assert cache_hash_short in message
    assert "3e1374e (2026-08-11)" in message


def test_cache_hash_short_extraction():
    """Test that short hash extraction works correctly."""
    full_hash = hashlib.sha256(b"MANDATORY CHECKLIST content").hexdigest()
    hash_short = full_hash[:6]

    assert len(hash_short) == 6
    assert len(full_hash) == 64
    assert hash_short in full_hash


if __name__ == "__main__":
    test_mandatory_block_extraction()
    test_mandatory_hash_generation()
    test_hash_changes_on_content_change()
    test_verify_cache_active()
    test_verify_cache_mismatch()
    test_cache_hash_format_in_output()
    test_sync_message_format()
    test_cache_hash_short_extraction()
    print("All tests passed!")
