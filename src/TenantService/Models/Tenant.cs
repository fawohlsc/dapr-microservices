namespace TenantService.Models;

public record struct Tenant
{
    // Regular expression checking for Guid e.g., af5cc56a-e164-43cc-8ab2-cf7a76ff5242
    [RegularExpression(@"^([0-9A-Fa-f]{8}[-][0-9A-Fa-f]{4}[-][0-9A-Fa-f]{4}[-][0-9A-Fa-f]{4}[-][0-9A-Fa-f]{12})$")]
    [Required]
    public string Id { get; init; }

    [MinLength(1)]
    [MaxLength(256)]
    [Required]
    public string Name { get; init; }

    [RegularExpression("free|standard|premium")]
    [Required]
    public string Sku { get; init; }

    public Tenant(string id, string name, string sku)
        => (Id, Name, Sku) = (id, name, sku);
}