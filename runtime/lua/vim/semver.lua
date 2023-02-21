local M = {}

---@private
--- Compares the prerelease component of the two versions.
---@param v1_parsed table Parsed version.
---@param v2_parsed table Parsed version.
---@return integer `-1` if `v1_parsed < v2_parsed`, `0` if `v1_parsed == v2_parsed`, `1` if `v1_parsed > v2_parsed`.
local function cmp_prerelease(v1_parsed, v2_parsed)
  if v1_parsed.prerelease and not v2_parsed.prerelease then
    return -1
  end
  if not v1_parsed.prerelease and v2_parsed.prerelease then
    return 1
  end
  if not v1_parsed.prerelease and not v2_parsed.prerelease then
    return 0
  end

  local v1_identifiers = vim.split(v1_parsed.prerelease, '.', { plain = true })
  local v2_identifiers = vim.split(v2_parsed.prerelease, '.', { plain = true })
  local i = 1
  local max = math.max(vim.tbl_count(v1_identifiers), vim.tbl_count(v2_identifiers))
  while i <= max do
    local v1_identifier = v1_identifiers[i]
    local v2_identifier = v2_identifiers[i]
    if v1_identifier ~= v2_identifier then
      local v1_num = tonumber(v1_identifier)
      local v2_num = tonumber(v2_identifier)
      local is_number = v1_num and v2_num
      if is_number then
        -- Number comparisons
        if not v1_num and v2_num then
          return -1
        end
        if v1_num and not v2_num then
          return 1
        end
        if v1_num == v2_num then
          return 0
        end
        if v1_num > v2_num then
          return 1
        end
        if v1_num < v2_num then
          return -1
        end
      else
        -- String comparisons
        if v1_identifier and not v2_identifier then
          return 1
        end
        if not v1_identifier and v2_identifier then
          return -1
        end
        if v1_identifier < v2_identifier then
          return -1
        end
        if v1_identifier > v2_identifier then
          return 1
        end
        if v1_identifier == v2_identifier then
          return 0
        end
      end
    end
    i = i + 1
  end

  return 0
end

---@private
--- Compares the version core component of the two versions.
---@param v1_parsed table Parsed version.
---@param v2_parsed table Parsed version.
---@return integer `-1` if `v1_parsed < v2_parsed`, `0` if `v1_parsed == v2_parsed`, `1` if `v1_parsed > v2_parsed`.
local function cmp_version_core(v1_parsed, v2_parsed)
  if
    v1_parsed.major == v2_parsed.major
    and v1_parsed.minor == v2_parsed.minor
    and v1_parsed.patch == v2_parsed.patch
  then
    return 0
  end

  if
    v1_parsed.major > v2_parsed.major
    or v1_parsed.minor > v2_parsed.minor
    or v1_parsed.patch > v2_parsed.patch
  then
    return 1
  end

  return -1
end

--- Compares two strings (`v1` and `v2`) in semver format.
---@param v1 string Version.
---@param v2 string Version to be compared with v1.
---@param opts table|nil Optional keyword arguments:
---                      - strict (boolean):  see `semver.parse` for details. Defaults to false.
---@return integer `-1` if `v1 < v2`, `0` if `v1 == v2`, `1` if `v1 > v2`.
function M.cmp(v1, v2, opts)
  opts = opts or { strict = false }
  local v1_parsed = M.parse(v1, opts)
  local v2_parsed = M.parse(v2, opts)

  local result = cmp_version_core(v1_parsed, v2_parsed)
  if result == 0 then
    result = cmp_prerelease(v1_parsed, v2_parsed)
  end
  return result
end

---@private
---@param labels string Prerelease and build component of semantic version string e.g. "-rc1+build.0".
---@return string|nil
local function parse_prerelease(labels)
  -- This pattern matches "-(alpha)+build.15".
  local result = labels:match('^-([^+]+)+.+$')
  if result then
    return result
  end
  -- This pattern matches "-(alpha)".
  result = labels:match('^-([^+]+)$')
  if result then
    return result
  end

  return nil
end

---@private
---@param labels string Prerelease and build component of semantic version string e.g. "-rc1+build.0".
---@return string|nil
local function parse_build(labels)
  -- Pattern matches "-alpha+(build.15)".
  local result = labels:match('^-[^+]++(.+)$')
  if result then
    return result
  end

  -- Pattern matches "+(build.15)".
  result = labels:match('^%+(%w[%.%w-]*)$')
  if result then
    return result
  end

  return nil
end

---@private
--- Extracts the major, minor, patch and preprelease and build components from
--- `version`.
---@param version string Version string
local function extract_components_strict(version)
  local major, minor, patch, prerelease_and_build = version:match('^v?(%d+)%.(%d+)%.(%d+)(.*)$')
  return tonumber(major), tonumber(minor), tonumber(patch), prerelease_and_build
end

---@private
--- Extracts the major, minor, patch and preprelease and build components from
--- `version`. When `minor` and `patch` components are not found (nil), coerce
--- them to 0.
---@param version string Version string
local function extract_components_loose(version)
  local major, minor, patch, prerelease_and_build = version:match('^v?(%d+)%.?(%d*)%.?(%d*)(.*)$')
  major = tonumber(major)
  minor = tonumber(minor) or 0
  patch = tonumber(patch) or 0
  return major, minor, patch, prerelease_and_build
end

---@private
--- Validates the prerelease and build string e.g. "-rc1+build.0". If the
--- prerelease, build or both are valid forms then it will return true, if it
--- is not of any valid form, it will return false.
---@param prerelease_and_build string
---@return boolean
local function is_prerelease_and_build_valid(prerelease_and_build)
  local has_build = prerelease_and_build:match('^%+[%w%.]+$')
  local has_prerelease = prerelease_and_build:match('^%-[%w%.]+$')
  local has_prerelease_and_build = prerelease_and_build:match('^%-[%w%.]+%+[%w%.]+')
  return has_build or has_prerelease or has_prerelease_and_build
end

---@private
---@param prerelease_and_build string
---@return boolean
local function has_prerelease_and_build(prerelease_and_build)
  return prerelease_and_build ~= nil and prerelease_and_build ~= ''
end

---@private
---@param version string
---@return string
local function create_err_msg(version)
  return string.format('%s is not a valid version', version)
end

--- Parses a semantically formatted version string into a table.
---
--- Supports leading "v" and leading and trailing whitespace in the version
--- string. e.g. `" v1.0.1-rc1+build.2"` , `"1.0.1-rc1+build.2"`, `"v1.0.1-rc1+build.2"`
--- and `"v1.0.1-rc1+build.2 "` will be parsed as:
---
--- `{ major = 1, minor = 0, patch = 1, prerelease = 'rc1', build = 'build.2' }`
---
---@param version string Version string to be parsed.
---@param opts table|nil Optional keyword arguments:
---                      - strict (boolean):  when set to `true` an error will be thrown for version
---                      strings which are not conforming to semver sepecifications (v2.0.0), (see
---                      semver.org/spec/v2.0.0.html for details), this means that
---                      `semver.parse('v1.2)` will throw an error. When set to `false`,
---                      `semver.parse('v1.2)` will coerce 'v1.2' to 'v1.2.0' and return the table:
---                      `{ major = 1, minor = 2, patch = 0 }`. Defaults to false.
---@return table parsed_version Parsed version table
function M.parse(version, opts)
  if type(version) ~= 'string' then
    error(create_err_msg(version))
  end

  opts = opts or { strict = false }

  version = vim.trim(version)

  local major, minor, patch, prerelease_and_build
  if opts.strict then
    major, minor, patch, prerelease_and_build = extract_components_strict(version)
  else
    major, minor, patch, prerelease_and_build = extract_components_loose(version)
  end

  -- If major is nil then that means that the version does not begin with a
  -- digit with or without a "v" prefix.
  if major == nil then
    error(create_err_msg(version))
  end

  if
    has_prerelease_and_build(prerelease_and_build)
    and not is_prerelease_and_build_valid(prerelease_and_build)
  then
    error(create_err_msg(version))
  end

  local prerelease = nil
  local build = nil
  if prerelease_and_build ~= nil then
    prerelease = parse_prerelease(prerelease_and_build)
    build = parse_build(prerelease_and_build)
  end

  return {
    major = major,
    minor = minor,
    patch = patch,
    prerelease = prerelease,
    build = build,
  }
end

return M
