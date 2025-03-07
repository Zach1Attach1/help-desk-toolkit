# Help Desk Toolkit

A comprehensive toolkit for IT Help Desk professionals, featuring practical tools, scripts, and documentation to streamline support operations.

![Help Desk Toolkit Banner](https://github.com/yourusername/help-desk-toolkit/raw/main/images/banner.png)

## 🔍 Overview

This repository contains resources I've developed to enhance IT support workflows. As an aspiring Help Desk Technician, I've created this toolkit to demonstrate my technical skills, problem-solving approach, and commitment to efficiency in IT support operations.

## 🛠️ Features

### 1. Troubleshooting Guides
- Comprehensive step-by-step guides for common desktop, laptop, and mobile device issues
- Printer connection and configuration troubleshooting
- Network connectivity diagnostics
- Software installation and update procedures

### 2. Automation Scripts
- User account setup automation (PowerShell)
- System health check scripts
- Automated maintenance task scheduler
- Remote support session preparation tools

### 3. Knowledge Base
- FAQ templates for common user questions
- Documentation standards and templates
- Hardware and software inventory tracking system
- Service request categorization framework

### 4. Remote Support Tools
- Remote session preparation checklists
- Screen sharing best practices
- Secure file transfer procedures
- Remote diagnostic techniques

## 💻 Technical Components

### Automated System Health Check
```powershell
# PowerShell script to check system health and generate report
param(
    [Parameter(Mandatory=$true)]
    [string]$ComputerName,
    
    [Parameter(Mandatory=$false)]
    [string]$OutputPath = ".\SystemHealthReports\"
)

# Create output directory if it doesn't exist
if (!(Test-Path $OutputPath)) {
    New-Item -ItemType Directory -Path $OutputPath | Out-Null
}

$report = @()
$date = Get-Date -Format "yyyy-MM-dd_HH-mm"
$outputFile = "$OutputPath\$ComputerName`_$date.html"

# Get system information
$systemInfo = Get-CimInstance -ClassName Win32_OperatingSystem -ComputerName $ComputerName
$report += "System: $($systemInfo.Caption) ($($systemInfo.Version))"
$report += "Last Boot: $($systemInfo.LastBootUpTime)"
$report += "Uptime: $([math]::Round(($systemInfo.LocalDateTime - $systemInfo.LastBootUpTime).TotalHours, 2)) hours"

# Get disk space information
$disks = Get-CimInstance -ClassName Win32_LogicalDisk -Filter "DriveType=3" -ComputerName $ComputerName
foreach ($disk in $disks) {
    $freeSpacePercent = [math]::Round(($disk.FreeSpace / $disk.Size) * 100, 2)
    $report += "Drive $($disk.DeviceID): $freeSpacePercent% free ($([math]::Round($disk.FreeSpace / 1GB, 2)) GB of $([math]::Round($disk.Size / 1GB, 2)) GB)"
}

# Get top 5 processes by memory usage
$processes = Get-Process -ComputerName $ComputerName | Sort-Object -Property WS -Descending | Select-Object -First 5
$report += "Top 5 memory-consuming processes:"
foreach ($process in $processes) {
    $report += "- $($process.ProcessName): $([math]::Round($process.WS / 1MB, 2)) MB"
}

# Check for pending updates
try {
    $updateSession = New-Object -ComObject Microsoft.Update.Session
    $updateSearcher = $updateSession.CreateUpdateSearcher()
    $pendingUpdates = $updateSearcher.Search("IsInstalled=0 and IsHidden=0").Updates.Count
    $report += "Pending updates: $pendingUpdates"
} catch {
    $report += "Could not check for pending updates: $($_.Exception.Message)"
}

# Generate HTML report
$htmlReport = @"



    System Health Report: $ComputerName
    
        body { font-family: Arial, sans-serif; margin: 20px; }
        h1 { color: #0066cc; }
        .section { margin-bottom: 20px; }
        .warning { color: orange; }
        .critical { color: red; }
        .good { color: green; }
    


    System Health Report: $ComputerName
    
        Generated: $date
        $($report -join "`n")
    


"@

# Save the report
$htmlReport | Out-File -FilePath $outputFile -Encoding utf8

Write-Output "Report generated at $outputFile"
```

### User Account Setup Script
```powershell
# PowerShell script to automate new user account setup
param(
    [Parameter(Mandatory=$true)]
    [string]$FirstName,
    
    [Parameter(Mandatory=$true)]
    [string]$LastName,
    
    [Parameter(Mandatory=$true)]
    [string]$Department,
    
    [Parameter(Mandatory=$true)]
    [string]$Title,
    
    [Parameter(Mandatory=$false)]
    [string]$Manager = "",
    
    [Parameter(Mandatory=$false)]
    [string]$Template = ""
)

# Configuration
$domain = "theamegroup.local"
$ouPath = "OU=$Department,OU=Users,DC=theamegroup,DC=local"
$userPrefix = "AME"

# Generate username (first initial + last name)
$username = "$userPrefix.$($FirstName.Substring(0,1))$LastName".ToLower()

# Check if username exists, append number if needed
$counter = 1
$originalUsername = $username
while (Get-ADUser -Filter "SamAccountName -eq '$username'" -ErrorAction SilentlyContinue) {
    $username = "$originalUsername$counter"
    $counter++
}

# Generate a temporary password
$passwordLength = 12
$nonAlphanumeric = 2
$upperCase = 2
$lowerCase = 2
$numbers = 2
$password = New-Password -Length $passwordLength -NonAlphanumeric $nonAlphanumeric -UpperCase $upperCase -LowerCase $lowerCase -Numbers $numbers

# Create the user
try {
    New-ADUser -Name "$FirstName $LastName" `
               -GivenName $FirstName `
               -Surname $LastName `
               -SamAccountName $username `
               -UserPrincipalName "$username@$domain" `
               -Path $ouPath `
               -Title $Title `
               -Department $Department `
               -Company "The AME Group" `
               -EmailAddress "$username@theamegroup.com" `
               -Enabled $true `
               -ChangePasswordAtLogon $true `
               -AccountPassword (ConvertTo-SecureString -AsPlainText $password -Force)
    
    # Add user to standard groups
    Add-ADGroupMember -Identity "All Users" -Members $username
    Add-ADGroupMember -Identity "$Department" -Members $username
    
    # If template user is specified, copy group memberships
    if ($Template -ne "") {
        $templateGroups = Get-ADPrincipalGroupMembership -Identity $Template | Where-Object {$_.Name -ne "Domain Users"}
        foreach ($group in $templateGroups) {
            Add-ADGroupMember -Identity $group -Members $username
        }
    }
    
    # Set manager if specified
    if ($Manager -ne "") {
        Set-ADUser -Identity $username -Manager $Manager
    }
    
    # Output results
    Write-Output "User created successfully:"
    Write-Output "Username: $username"
    Write-Output "Temporary password: $password"
    Write-Output "User must change password at next logon"
    
} catch {
    Write-Error "Failed to create user: $_"
}
```

### Ticket Tracking System (Python)
```python
import os
import json
import datetime
import uuid
from tabulate import tabulate

class TicketSystem:
    def __init__(self, data_file="tickets.json"):
        self.data_file = data_file
        self.tickets = self._load_tickets()
        self.statuses = ["New", "In Progress", "Waiting", "Resolved", "Closed"]
        self.priorities = ["Low", "Medium", "High", "Critical"]
        self.categories = ["Hardware", "Software", "Network", "Account", "Other"]
    
    def _load_tickets(self):
        if os.path.exists(self.data_file):
            with open(self.data_file, 'r') as f:
                return json.load(f)
        return []
    
    def _save_tickets(self):
        with open(self.data_file, 'w') as f:
            json.dump(self.tickets, f, indent=2)
    
    def create_ticket(self, requester, email, category, subject, description, priority="Medium"):
        if category not in self.categories:
            raise ValueError(f"Category must be one of: {', '.join(self.categories)}")
        
        if priority not in self.priorities:
            raise ValueError(f"Priority must be one of: {', '.join(self.priorities)}")
        
        ticket_id = str(uuid.uuid4())[:8].upper()
        now = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        
        ticket = {
            "id": ticket_id,
            "requester": requester,
            "email": email,
            "category": category,
            "subject": subject,
            "description": description,
            "status": "New",
            "priority": priority,
            "created": now,
            "updated": now,
            "assigned_to": "",
            "history": [
                {"timestamp": now, "action": "Ticket created", "by": "System"}
            ]
        }
        
        self.tickets.append(ticket)
        self._save_tickets()
        return ticket_id
    
    def update_ticket(self, ticket_id, status=None, priority=None, assigned_to=None, notes=None, updated_by="System"):
        ticket = next((t for t in self.tickets if t["id"] == ticket_id), None)
        if not ticket:
            raise ValueError(f"Ticket {ticket_id} not found")
        
        now = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        actions = []
        
        if status and status in self.statuses:
            actions.append(f"Status changed from {ticket['status']} to {status}")
            ticket["status"] = status
        
        if priority and priority in self.priorities:
            actions.append(f"Priority changed from {ticket['priority']} to {priority}")
            ticket["priority"] = priority
        
        if assigned_to is not None:
            if assigned_to == "":
                actions.append(f"Unassigned from {ticket['assigned_to']}")
            else:
                actions.append(f"Assigned to {assigned_to}")
            ticket["assigned_to"] = assigned_to
        
        if notes:
            actions.append(f"Notes added: {notes}")
        
        if actions:
            ticket["updated"] = now
            for action in actions:
                ticket["history"].append({
                    "timestamp": now,
                    "action": action,
                    "by": updated_by
                })
            
            self._save_tickets()
            return True
        
        return False
    
    def get_ticket(self, ticket_id):
        return next((t for t in self.tickets if t["id"] == ticket_id), None)
    
    def list_tickets(self, status=None, priority=None, assigned_to=None):
        filtered = self.tickets
        
        if status:
            filtered = [t for t in filtered if t["status"] == status]
        
        if priority:
            filtered = [t for t in filtered if t["priority"] == priority]
            
        if assigned_to:
            filtered = [t for t in filtered if t["assigned_to"] == assigned_to]
        
        return filtered
    
    def display_tickets(self, tickets=None):
        if tickets is None:
            tickets = self.tickets
            
        if not tickets:
            print("No tickets found")
            return
            
        table_data = []
        for t in tickets:
            table_data.append([
                t["id"],
                t["subject"][:30] + "..." if len(t["subject"]) > 30 else t["subject"],
                t["status"],
                t["priority"],
                t["requester"],
                t["assigned_to"] or "Unassigned",
                t["updated"]
            ])
            
        headers = ["ID", "Subject", "Status", "Priority", "Requester", "Assigned To", "Last Updated"]
        print(tabulate(table_data, headers=headers, tablefmt="grid"))

    def generate_report(self, report_type="summary"):
        if report_type == "summary":
            # Generate summary statistics
            total = len(self.tickets)
            by_status = {}
            for status in self.statuses:
                by_status[status] = len([t for t in self.tickets if t["status"] == status])
                
            by_priority = {}
            for priority in self.priorities:
                by_priority[priority] = len([t for t in self.tickets if t["priority"] == priority])
                
            unassigned = len([t for t in self.tickets if not t["assigned_to"]])
            
            print("=== Ticket Summary Report ===")
            print(f"Total tickets: {total}")
            print("\nBy Status:")
            for status, count in by_status.items():
                print(f"  {status}: {count}")
                
            print("\nBy Priority:")
            for priority, count in by_priority.items():
                print(f"  {priority}: {count}")
                
            print(f"\nUnassigned tickets: {unassigned}")
            
        elif report_type == "response_time":
            # This would calculate average response times
            # For simplicity, we'll just print a placeholder
            print("Response time report (functionality to be implemented)")

# Example usage
if __name__ == "__main__":
    # Create a ticket system
    system = TicketSystem()
    
    # Create some sample tickets
    system.create_ticket("John Smith", "john@example.com", "Hardware", 
                         "Laptop won't boot", "My laptop shows a black screen when powering on.",
                         priority="High")
    
    system.create_ticket("Sarah Johnson", "sarah@example.com", "Software", 
                         "Can't install application", "Getting error 0x80070643 when installing the software.",
                         priority="Medium")
    
    system.create_ticket("Michael Wong", "michael@example.com", "Network", 
                         "Can't connect to VPN", "Receiving timeout error when connecting to the company VPN.",
                         priority="High")
    
    # Update a ticket
    tickets = system.list_tickets()
    if tickets:
        system.update_ticket(tickets[0]["id"], status="In Progress", 
                            assigned_to="Tech Support", 
                            notes="Contacted user to schedule remote session",
                            updated_by="Help Desk")
    
    # Display all tickets
    print("\nAll Tickets:")
    system.display_tickets()
    
    # Display only high priority tickets
    print("\nHigh Priority Tickets:")
    high_priority = system.list_tickets(priority="High")
    system.display_tickets(high_priority)
    
    # Generate summary report
    print("\n")
    system.generate_report()
```

### Remote Support Checklist
```markdown
# Remote Support Session Checklist

## Pre-Session Preparation
- [ ] Verify user identity and contact information
- [ ] Confirm issue description and priority
- [ ] Check for similar recent tickets or known issues
- [ ] Prepare appropriate troubleshooting tools
- [ ] Schedule session time with user

## Session Initialization
- [ ] Explain the remote support process to the user
- [ ] Obtain explicit permission to access their system
- [ ] Verify the connection is secure
- [ ] Explain that you will narrate your actions throughout
- [ ] Ask if they have any questions before proceeding

## During Session
- [ ] Narrate actions as you perform them
- [ ] Document all findings and steps taken
- [ ] Take screenshots of error messages (with permission)
- [ ] If unable to resolve, collect diagnostic information
- [ ] Be mindful of user's time and explain any delays

## Session Closure
- [ ] Summarize actions taken and results
- [ ] Verify with user that the issue is resolved
- [ ] Provide preventative advice if applicable
- [ ] Explain next steps if issue is not resolved
- [ ] Ask if the user has additional questions
- [ ] Thank the user for their time and patience
- [ ] Properly terminate remote connection

## Post-Session Tasks
- [ ] Update ticket with detailed notes
- [ ] Attach any relevant screenshots or logs
- [ ] Document solution in knowledge base if applicable
- [ ] Follow up with user next day for persistent issues
- [ ] Identify any process improvements based on session
```

## 📋 Implementation Plan

### Phase 1: Knowledge Base Development
- Create comprehensive documentation for common IT issues
- Develop standardized troubleshooting workflows
- Establish documentation standards

### Phase 2: Script Development
- Write and test PowerShell scripts for Windows environments
- Develop Bash scripts for Mac/Linux environments
- Create cross-platform Python utilities

### Phase 3: Testing and Refinement
- Conduct usability testing of all tools and scripts
- Refine based on feedback and performance
- Document test results and improvements

## 🔄 Continuous Improvement
This toolkit is continuously updated based on:
- New technology trends
- Emerging support challenges
- Efficiency improvements
- User feedback

## 📚 Resources
- [Microsoft Support Documentation](https://docs.microsoft.com/en-us/windows/client-management/)
- [Apple Support Resources](https://support.apple.com/guide)
- [PowerShell Documentation](https://docs.microsoft.com/en-us/powershell/)
- [Help Desk Institute Best Practices](https://www.thinkhdi.com/library/supportworld.aspx)

## 📄 License
This project is licensed under the MIT License - see the LICENSE file for details.

---

Created by [Your Name] | [your.email@example.com]
