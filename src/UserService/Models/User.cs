namespace UserService.Models
{
    public record struct User
    {
        // Regular expression checking for Guid e.g., af5cc56a-e164-43cc-8ab2-cf7a76ff5242
        [RegularExpression(@"^([0-9A-Fa-f]{8}[-][0-9A-Fa-f]{4}[-][0-9A-Fa-f]{4}[-][0-9A-Fa-f]{4}[-][0-9A-Fa-f]{12})$")]
        [Required]
        public string Id { get; init; }

        [MinLength(2)]
        [MaxLength(35)]
        [Required]
        public string FirstName { get; init; }

        [MinLength(2)]
        [MaxLength(35)]
        [Required]
        public string LastName { get; init; }

        [EmailAddress]
        [Required]
        public string EmailAddress { get; init; }

        // Regular expression checking for Guid e.g., af5cc56a-e164-43cc-8ab2-cf7a76ff5242
        [RegularExpression(@"^([0-9A-Fa-f]{8}[-][0-9A-Fa-f]{4}[-][0-9A-Fa-f]{4}[-][0-9A-Fa-f]{4}[-][0-9A-Fa-f]{12})$")]
        [Required]
        public string TenantId { get; init; }

        public User(string id, string firstName, string lastName, string emailAddress, string tenantId)
            => (Id, FirstName, LastName, EmailAddress, TenantId) = (id, firstName, lastName, emailAddress, tenantId);
    }
}