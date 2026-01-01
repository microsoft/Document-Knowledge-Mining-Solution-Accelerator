// Copyright (c) Microsoft. All rights reserved.

using System;
using System.Diagnostics.CodeAnalysis;
using System.Text.RegularExpressions;
namespace Microsoft.KernelMemory.Models;

[Experimental("KMEXP00")]
public static class IndexName
{
    // Only allow index names that are valid SQL identifiers (start with a letter or underscore,
    // followed by letters, digits, or underscores, max 128 chars). This mirrors the constraints
    // enforced by SqlServerMemory.NormalizeIndexName.
    private static readonly Regex s_safeSqlIdentifierRegex = new("^[a-zA-Z_][a-zA-Z0-9_]{0,127}$", RegexOptions.Compiled);
    /// <summary>
    /// Clean the index name, returning a non empty, validated value if possible.
    /// </summary>
    /// <param name="name">Input index name</param>
    /// <param name="defaultName">Default value to fall back when input is empty</param>
    /// <returns>Non empty, validated index name</returns>
    public static string CleanName(string? name, string? defaultName)
    {
        if (string.IsNullOrWhiteSpace(name) && string.IsNullOrWhiteSpace(defaultName))
        {
            throw new ArgumentNullException(nameof(defaultName),
                "Both index name and default fallback value are empty. Provide an index name or a default value to use when the index name is empty.");
        }
        // Normalize whitespace on default name first
        defaultName = defaultName?.Trim() ?? string.Empty;
         // Prefer the explicit name when provided; otherwise, use the default
         var effectiveName = name is null ? defaultName : name.Trim();
        if (string.IsNullOrWhiteSpace(effectiveName))
        {
            throw new ArgumentNullException(nameof(name),
                "The resolved index name is empty. Provide a non-empty index name or default value.");
        }

        // Normalize case to keep index names consistent
        effectiveName = effectiveName.ToLowerInvariant();

        // Enforce safe SQL-identifier constraints used by the SQL layer
        if (!s_safeSqlIdentifierRegex.IsMatch(effectiveName))
        {
            throw new ArgumentException(
                "Invalid index name. Allowed: letters, digits, underscores, max length 128, cannot start with digit.",
                nameof(name));
        }

        return effectiveName;
    }
}
