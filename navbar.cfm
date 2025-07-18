<!--- Navigation Bar --->
<nav class="navbar navbar-expand-lg navbar-dark bg-dark">
    <div class="container-fluid">
        <!--- App Title --->
        <a class="navbar-brand" href="#">DocketWatch</a>

        <!--- Navbar Toggle (For Mobile View) --->
        <button class="navbar-toggler" type="button" data-bs-toggle="collapse" data-bs-target="#navbarNav">
            <span class="navbar-toggler-icon"></span>
        </button>

        <div class="collapse navbar-collapse" id="navbarNav">
            <ul class="navbar-nav">
                <!--- Dashboard --->
                <li class="nav-item">
                    <a class="nav-link active" href="#">Dashboard</a>
                </li>

                <!--- Case Management Dropdown --->
                <li class="nav-item dropdown">
                    <a class="nav-link dropdown-toggle" href="#" id="navbarDropdown" role="button" data-bs-toggle="dropdown">
                        Case Management
                    </a>
                    <ul class="dropdown-menu">
                        <li><a class="dropdown-item" href="">New Cases Review</a></li>
                        <li><a class="dropdown-item" href="../index.cfm?status=Tracked">Tracked Cases</a></li>
                        <li><a class="dropdown-item" href="case_events.cfm">Case Events</a></li>
                        <li><a class="dropdown-item" href="latest_pacer_pdfs.cfm">Latest Pacer PDFs</a></li>
                        <li><a class="dropdown-item" href="case_matches.cfm">Celebrity Matches</a></li>
                        <li><a class="dropdown-item" href="pardons.cfm">Pardons</a></li>
                        <li><a class="dropdown-item" href="calendar.cfm">Calendar</a></li>
                    </ul>
                </li>

                <!--- Reports Dropdown --->
                <li class="nav-item dropdown">
                    <a class="nav-link dropdown-toggle" href="#" id="navbarDropdown" role="button" data-bs-toggle="dropdown">
                        Reports
                    </a>
                    <ul class="dropdown-menu">
                        <li><a class="dropdown-item" href="case_tracking_summary.cfm">Tracking Summary</a></li>
                        <li><a class="dropdown-item" href="scheduled_task_log.cfm">Scheduled Log</a></li>
                        <li><a class="dropdown-item" href="pacer_costs.cfm">Pacer Costs</a></li>
                        <li><a class="dropdown-item" href="not_found.cfm">Tracked Cases Not Found</a></li>
                    </ul>
                </li>

                <!--- Admin Dropdown --->
                <li class="nav-item dropdown">
                    <a class="nav-link dropdown-toggle" href="#" id="navbarDropdownAdmin" role="button" data-bs-toggle="dropdown">
                        Admin
                    </a>
                    <ul class="dropdown-menu">
                        <li><a class="dropdown-item" href="celebrity_gallery.cfm">Celebrities</a></li>
                        <li><a class="dropdown-item" href="tools.cfm">Tools</a></li>
                    </ul>
                </li>

                <!--- Archive Dropdown --->
                <li class="nav-item dropdown">
                    <a class="nav-link dropdown-toggle" href="#" id="navbarDropdown" role="button" data-bs-toggle="dropdown">
                        Archive
                    </a>
                    <ul class="dropdown-menu">
                        <li><a class="dropdown-item" href="../index.cfm?status=Removed">Removed Cases</a></li>
                    </ul>
                </li>
            </ul>

            <!--- Right-aligned Logout link --->
            <ul class="navbar-nav ms-auto">
                <li class="nav-item">
                    <a class="nav-link text-danger" href="../index.cfm?logout=true&m=d">Logout</a>
                </li>
            </ul>

        </div>
    </div>
</nav>
